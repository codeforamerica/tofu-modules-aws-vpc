locals {
  azs    = data.aws_availability_zones.available.names
  prefix = "${var.project}-${var.environment}"

  # If the number of subnets exceeds the number of availability zones, don't
  # attempt to use more availability zones than exist.
  az_count = min(
    length(local.azs),
    max(length(var.private_subnets), length(var.public_subnets))
  )

  gateway_endpoint_services = setunion(
    toset(["s3"]),
    var.additional_gateway_endpoints
  )
  gateway_endpoints = {
    for service in local.gateway_endpoint_services : service => {
      service      = service
      service_type = "Gateway"
      tags         = { Name = "${local.prefix}-${service}" }
    }
  }

  # Define the set of services that require interface endpoints.
  interface_endpoint_services = setunion(
    toset([
      "ec2",
      "ec2messages",
      "ecr.api",
      "ecr.dkr",
      "guardduty-data",
      "ssm",
      "ssm-contacts",
      "ssm-incidents",
      "ssmmessages"
    ]),
    var.additional_interface_endpoints
  )
  interface_endpoints = {
    for service in local.interface_endpoint_services : service => {
      service             = service
      tags                = { Name = "${local.prefix}-${service}" }
      subnet_ids          = data.aws_subnets.endpoints[service].ids
      private_dns_enabled = true
    }
  }

  # Define inbound and outbound ACL rules for any peering connections.
  peer_inbound_acls = [
    for peer in var.peers : {
      action      = "allow"
      cidr_block  = peer.cidr
      from_port   = 0
      protocol    = -1
      rule_number = 200
      to_port     = 0
    }
  ]
  peer_outbound_acls = [
    for peer in var.peers : {
      action      = "allow"
      cidr_block  = peer.cidr
      from_port   = 0
      protocol    = -1
      rule_number = 200
      to_port     = 0
    }
  ]

  # Create a set of peering routes based on the provided peers and the created
  # private route tables.
  peer_cidrs = [
    for key, value in var.peers : {
      key  = key
      cidr = value.cidr
    }
  ]
  peer_routes = [
    for pair in setproduct(local.peer_cidrs, module.vpc.private_route_table_ids) : {
      cidr     = pair[0].cidr
      key      = pair[0].key
      table_id = pair[1]
    }
  ]
}
