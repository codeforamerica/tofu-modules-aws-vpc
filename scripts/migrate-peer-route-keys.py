#!/usr/bin/env python3
"""Generate `tofu state mv` commands for the 2.0.0 aws_route.peer key change.

Version 2.0.0 changed the for_each key on aws_route.peer from
"<peer>-<route-table-id>" to "<peer>-<route-table-index>", because the route
table IDs do not exist yet on a greenfield deployment and an unknown key makes
the plan fail.

Existing deployments have to move their state entries before the first plan
against 2.0.0. Skipping this does not just drop the routes briefly. OpenTofu
puts no ordering edge between the old and new instances, so the creates start
before the destroys finish, and the AWS provider rejects a CreateRoute while a
route for that destination is still present. A losing race leaves the apply
errored with the old routes already deleted.

Run this from the config directory, after `tofu init` and before bumping the
module ref. It reads state and prints commands. It never modifies anything.

    ./migrate-peer-route-keys.py                 # print the commands
    ./migrate-peer-route-keys.py | sh            # run them

Use --binary terraform if the config is on Terraform instead of OpenTofu.
"""

import argparse
import json
import re
import shlex
import subprocess
import sys
from collections import defaultdict

OLD_KEY = re.compile(r"^(?P<peer>.+)-(?P<table_id>rtb-[0-9a-f]+)$")


def pull_state(binary):
    try:
        result = subprocess.run(
            [binary, "state", "pull"],
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        sys.exit(f"{binary} is not on PATH.")
    except subprocess.CalledProcessError as error:
        sys.exit(f"{binary} state pull failed.\n{error.stderr.strip()}")

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        sys.exit("State did not parse as JSON. Has the config been initialized?")


def address(resource, index_key=None):
    """Build a full resource address from a state resource entry."""
    parts = []
    if resource.get("module"):
        parts.append(resource["module"])
    if resource.get("mode") == "data":
        parts.append("data")
    parts.append(f"{resource['type']}.{resource['name']}")

    joined = ".".join(parts)
    if index_key is None:
        return joined
    return f"{joined}[{json.dumps(index_key)}]"


def route_table_ids_by_module(state):
    """Map each VPC module path to its ordered list of private route table IDs.

    The upstream terraform-aws-modules/vpc module creates aws_route_table.private
    with a count, so the instance index is the position the wrapper module's
    private_route_table_ids output preserves.
    """
    tables = defaultdict(dict)
    for resource in state.get("resources", []):
        if resource.get("type") != "aws_route_table":
            continue
        if resource.get("name") != "private":
            continue
        if resource.get("mode") != "managed":
            continue

        module = resource.get("module", "")
        for instance in resource.get("instances", []):
            index = instance.get("index_key")
            table_id = instance.get("attributes", {}).get("id")
            if index is None or table_id is None:
                continue
            tables[module][table_id] = index

    return tables


def owning_vpc_module(route_module, table_modules):
    """Find the VPC module whose route tables belong to this aws_route.peer.

    aws_route.peer lives in the wrapper module and the route tables live in the
    nested "vpc" module underneath it, so the nested path is the route module
    path plus ".module.vpc".
    """
    expected = f"{route_module}.module.vpc" if route_module else "module.vpc"
    if expected in table_modules:
        return expected

    # Fall back to any nested module under this one, in case the child module
    # was given a different label.
    prefix = f"{route_module}.module." if route_module else "module."
    candidates = [path for path in table_modules if path.startswith(prefix)]
    if len(candidates) == 1:
        return candidates[0]
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--binary",
        default="tofu",
        help="CLI to call, defaults to tofu.",
    )
    args = parser.parse_args()

    state = pull_state(args.binary)
    table_modules = route_table_ids_by_module(state)

    moves = []
    unresolved = []

    for resource in state.get("resources", []):
        if resource.get("type") != "aws_route" or resource.get("name") != "peer":
            continue
        if resource.get("mode") != "managed":
            continue

        route_module = resource.get("module", "")
        vpc_module = owning_vpc_module(route_module, table_modules)
        lookup = table_modules.get(vpc_module, {}) if vpc_module else {}

        for instance in resource.get("instances", []):
            old_key = instance.get("index_key")
            if not isinstance(old_key, str):
                continue

            match = OLD_KEY.match(old_key)
            if not match:
                unresolved.append((address(resource, old_key), "key is already migrated or has an unexpected shape"))
                continue

            table_id = match.group("table_id")
            if table_id not in lookup:
                unresolved.append((address(resource, old_key), f"no private route table {table_id} found in state"))
                continue

            new_key = f"{match.group('peer')}-{lookup[table_id]}"
            moves.append((address(resource, old_key), address(resource, new_key)))

    if not moves and not unresolved:
        print("# No aws_route.peer entries found in state. Nothing to move.")
        return

    for source, destination in moves:
        print(f"{shlex.quote(args.binary)} state mv {shlex.quote(source)} {shlex.quote(destination)}")

    if unresolved:
        print(file=sys.stderr)
        for addr, reason in unresolved:
            print(f"# SKIPPED {addr}: {reason}", file=sys.stderr)
        print(
            f"# {len(unresolved)} entry(ies) skipped. Review them before applying.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
