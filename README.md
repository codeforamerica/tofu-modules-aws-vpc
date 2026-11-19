# AWS VPC Module

[![GitHub Release][badge-release]][latest-release]

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

By default, each peer's NACL rules allow all ports and protocols from the
peer's CIDR. To narrow that down, pass `from_port`, `to_port`, and/or
`protocol`:

```hcl
peers = {
  aptible = {
    account_id = "123456789012",
    vpc_id     = "vpc-012ab34cde5678fa9",
    region     = "us-east-1",
    cidr       = "10.123.0.0/16",
    from_port  = 5432,
    to_port    = 5432,
    protocol   = 6
  }
}
```

### Endpoints

By default, this module creates the following VPC endpoints:

- **Gateway:** S3
- **Interface:** ec2, ec2messages, ecr.api, ecr.dkr, guardduty-data, ssm,
  ssm-contacts, ssm-incidents, ssmmessages

To add additional endpoints, you can use the `additional_gateway_endpoints` and
`additional_interface_endpoints` inputs.

```hcl
additional_gateway_endpoints = ["dynamodb"]
additional_interface_endpoints = ["athena", "glue"]
```

### VPC Lattice

To share resources in this VPC with other accounts through [VPC
Lattice][vpc-lattice], enable a resource gateway. It'll be created in the
private subnets with a dedicated security group whose egress is limited to the
specified ports and CIDRs.

```hcl
resource_gateway = {
  ports = [5432]
  cidrs = ["10.0.20.0/24"]
}
```

To access resources shared by other accounts, create resource endpoints. Each
endpoint has private DNS enabled by default, and a security group that only
allows ingress on the given ports from the listed CIDRs and security groups. If
the resource configuration has no verified custom domain name, set
`private_dns = false`. Endpoints don't have an egress, so the security group has
no egress rules.


```hcl
resource_endpoints = {
  database = {
    resource_configuration_arn = "arn:aws:vpc-lattice:us-east-1:111111111111:resourceconfiguration/rcfg-0123456789abcdef0"
    ports                      = [5432]
    security_group_ids         = ["sg-0123456789abcdef0"]
  }
}
```

## Inputs

| Name                           | Description                                                                                                                                                      | Type     | Default | Required |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------- | -------- |
| cidr                           | IPv4 CIDR block for the VPC.                                                                                                                                     | `string` | n/a     | yes      |
| logging_key_id                 | KMS key to use for log encryption.                                                                                                                               | `string` | n/a     | yes      |
| private_subnets                | List of private subnet CIDR blocks.                                                                                                                              | `list`   | n/a     | yes      |
| project                        | Name of the project.                                                                                                                                             | `string` | n/a     | yes      |
| public_subnets                 | List of public subnet CIDR blocks.                                                                                                                               | `list`   | n/a     | yes      |
| additional_gateway_endpoints   | Gateway endpoint service names to create in addition to the S3 default.                                                                                          | `list`   | `[]`    | no       |
| additional_interface_endpoints | Interface endpoint service names to create in addition to the defaults.                                                                                          | `list`   | `[]`    | no       |
| log_retention_period           | Retention period for flow logs, in days.                                                                                                                         | `string` | 30      | no       |
| environment                    | Environment for the project.                                                                                                                                     | `string` | `"dev"` | no       |
| peers                          | List of VPC peering connections.                                                                                                                                 | `map`    | `{}`    | no       |
| [resource_endpoints]           | VPC Lattice resource endpoints to create, keyed by name. Ingress to each endpoint is allowed only on the listed ports from the listed CIDRs and security groups. | `map`    | `{}`    | no       |
| [resource_gateway]             | Create a VPC Lattice resource gateway in the private subnets. Egress from the gateway is limited to the given ports and CIDRs. Disabled when `null`.             | `object` | `null`  | no       |
| single_nat_gateway             | Create a single NAT gateway, rather than 1 in each private subnet. **_Cheaper, but not highly available._**                                                      | `bool`   | `false` | no       |
| tags                           | Optional tags to be applied to all resources.                                                                                                                    | `list`   | `[]`    | no       |

### resource_endpoints

To add [resource endpoints][aws-resource-endpoint] for resources shared through
a resource gateway, define them under the `resource_endpoints` map. Each key
represents the name of the endpoint, and the value is an object with the
endpoint's configuration.

| Name                       | Description                                                                               | Type     | Default | Required |
| -------------------------- | ----------------------------------------------------------------------------------------- | -------- | ------- | -------- |
| ports                      | TCP ports on which ingress to the endpoint is allowed.                                    | `set`    | n/a     | yes      |
| resource_configuration_arn | ARN of the VPC Lattice resource configuration to connect to.                              | `string` | n/a     | yes      |
| cidrs                      | CIDR blocks that are allowed to connect to the endpoint.                                  | `list`   | `[]`    | no       |
| private_dns                | Enable private DNS. Requires a verified custom domain name on the resource configuration. | `bool`   | `true`  | no       |
| security_group_ids         | IDs of security groups that are allowed to connect to the endpoint.                       | `list`   | `[]`    | no       |

### resource_gateway

Creating a [resource gateway][aws-resource-gateway] allows you to share resource
in your VPC with VPCs in other accounts.

Leave the value `null` to disable.

| Name                   | Description                                                                                                                  | Type     | Default  | Required |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | -------- |
| ports                  | TCP ports to which egress from the gateway is allowed.                                                                       | `set`    | n/a      | yes      |
| cidrs                  | CIDR blocks to which egress from the gateway is allowed.                                                                     | `list`   | n/a      | yes      |
| ip_address_type        | IP address type used by the gateway (`IPV4`, `IPV6`, or `DUALSTACK`).                                                        | `string` | `"IPV4"` | no       |
| ipv4_addresses_per_eni | Number of IPv4 addresses assigned to each of the gateway's elastic network interfaces. Leave `null` to use Amazon's default. | `number` | `null`   | no       |

## Outputs

| Name                        | Description                                                                                              | Type     |
| --------------------------- | -------------------------------------------------------------------------------------------------------- | -------- |
| availability_zones          | The availability zones in which the VPC subnets are created.                                             | `list`   |
| endpoint_ids                | Map of created VPC endpoints keyed by service name.                                                      | `map`    |
| endpoints_security_group_id | ID of the security group attached to the interface VPC endpoints.                                        | `string` |
| peer_ids                    | The IDs of any created VPC peering connections.                                                          | `list`   |
| private_subnets             | The IDs of the private subnets in the VPC.                                                               | `list`   |
| private_subnets_cidr_blocks | The CIDR blocks of the private subnets in the VPC.                                                       | `list`   |
| public_subnets              | The IDs of the public subnets in the VPC.                                                                | `list`   |
| public_subnets_cidr_blocks  | The CIDR blocks of the public subnets in the VPC.                                                        | `list`   |
| resource_endpoints          | Map of created VPC Lattice resource endpoints keyed by name, each with its `id` and `security_group_id`. | `map`    |
| resource_gateway            | The VPC Lattice resource gateway, if created, with its ARN, ID, and security group ID.                   | `object` |
| vpc_id                      | The ID of the VPC.                                                                                       | `string` |

[aws-resource-endpoint]: https://docs.aws.amazon.com/vpc/latest/privatelink/use-resource-endpoint.html
[aws-resource-gateway]: https://docs.aws.amazon.com/vpc/latest/privatelink/resource-gateway.html
[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-aws-vpc?logo=github&label=Latest%20Release
[latest-release]: https://github.com/codeforamerica/tofu-modules-aws-vpc/releases/latest
[resource_endpoints]: #resource_endpoints
[resource_gateway]: #resource_gateway
[vpc-lattice]: https://docs.aws.amazon.com/vpc-lattice/latest/ug/what-is-vpc-lattice.html
