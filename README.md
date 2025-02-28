# AWS VPC Module

[![Main Checks][badge-checks]][code-checks] [![GitHub Release][badge-release]][latest-release]

This module sets up a standard VPC with public and private subnets, NAT
gateway(s), service endpoints, and routing.

Creates endpoints for the following services: EC2, ECR, GuardDuty, S3, and SSM

## Usage

Add this module to your `main.tf` (or appropriate) file and configure the inputs
to match your desired configuration. For example, to create a VPC with 3 public
and private subnets, you could use the following configuration:

```hcl
module "vpc" {
  source = "github.com/codeforamerica/tofu-modules-aws-vpc?ref=1.1.1"

  project        = "my-project"
  environment    = "dev"
  cidr           = "10.0.20.0/22"
  logging_key_id = module.logging.kms_key_arn

  private_subnets = ["10.0.22.0/26", "10.0.22.64/26", "10.0.22.128/26"]
  public_subnets  = ["10.0.20.0/26", "10.0.20.64/26", "10.0.20.128/26"]
}
```

Make sure you re-run `tofu init` after adding the module to your configuration.

```bash
tofu init
tofu plan
```

To update the source for this module, pass `-upgrade` to `tofu init`:

```bash
tofu init -upgrade
```

### VPC Peers

You can create VPC peering connections by passing a named map of VPCs to peer.
This will only initiate the peering connection from the VPC created by this, the
peer must be approved on the other side before it can be used.

For example:

```hcl
peers = {
  aptible = {
    account_id = "123456789012",
    vpc_id     = "vpc-012ab34cde5678fa9",
    region     = "us-east-1",
    cidr       = "10.123.0.0/16"
  }
}
```

## Inputs

| Name                 | Description                                                                                                 | Type     | Default | Required |
|----------------------|-------------------------------------------------------------------------------------------------------------|----------|---------|----------|
| cidr                 | IPv4 CIDR block for the VPC.                                                                                | `string` | n/a     | yes      |
| logging_key_id       | KMS key to use for log encryption.                                                                          | `string` | n/a     | yes      |
| private_subnets      | List of private subnet CIDR blocks.                                                                         | `list`   | n/a     | yes      |
| project              | Name of the project.                                                                                        | `string` | n/a     | yes      |
| public_subnets       | List of public subnet CIDR blocks.                                                                          | `list`   | n/a     | yes      |
| log_retention_period | Retention period for flow logs, in days.                                                                    | `string` | 30      | no       |
| environment          | Environment for the project.                                                                                | `string` | `"dev"` | no       |
| peers                | List of VPC peering connections.                                                                            | `map`    | `{}`    | no       |
| single_nat_gateway   | Create a single NAT gateway, rather than 1 in each private subnet. **_Cheaper, but not highly available._** | `bool`   | `false` | no       |
| tags                 | Optional tags to be applied to all resources.                                                               | `list`   | `[]`    | no       |

## Outputs

| Name                        | Description                             | Type     |
|-----------------------------|-----------------------------------------|----------|
| availability_zones          | The availability zones in which the VPC subnets are created. | `list`   |
| peer_ids                    | The IDs of any created VPC peering connections. | `list`   |
| private_subnets             | The IDs of the private subnets in the VPC.             | `list`   |
| private_subnets_cidr_blocks | The CIDR blocks of the private subnets in the VPC.           | `list`   |
| public_subnets              | The IDs of the public subnets in the VPC.               | `list`   |
| public_subnets_cidr_blocks  | The CIDR blocks of the public subnets in the VPC.            | `list`   |
| vpc_id                      | The ID of the VPC.                  | `string` |

[badge-checks]: https://github.com/codeforamerica/tofu-modules-aws-vpc/actions/workflows/main.yaml/badge.svg
[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-aws-vpc?logo=github&label=Latest%20Release
[code-checks]: https://github.com/codeforamerica/tofu-modules-aws-vpc/actions/workflows/main.yaml
[latest-release]: https://github.com/codeforamerica/tofu-modules-aws-vpc/releases/latest
