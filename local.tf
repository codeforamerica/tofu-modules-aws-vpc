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
      service         = service
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = { Name = "${local.prefix}-${service}" }
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

  # Define inbound and outbound ACL rules for any peering connections. Rule
  # numbers are offset by index so multiple peers don't collide.
  peer_inbound_acls = [
    for index, peer in values(var.peers) : {
      action      = "allow"
      cidr_block  = peer.cidr
      from_port   = peer.from_port
      protocol    = peer.protocol
      rule_number = 200 + index
      to_port     = peer.to_port
    }
  ]
  peer_outbound_acls = [
    for index, peer in values(var.peers) : {
      action      = "allow"
      cidr_block  = peer.cidr
      from_port   = peer.from_port
      protocol    = peer.protocol
      rule_number = 200 + index
      to_port     = peer.to_port
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

  # Build the egress rules for the resource gateway.
  resource_gateway_rules = var.resource_gateway == null ? {} : {
    for rule in setproduct(range(length(var.resource_gateway.cidrs)), var.resource_gateway.ports) :
    "${rule[0]}:${rule[1]}" => {
      cidr = var.resource_gateway.cidrs[rule[0]]
      port = rule[1]
    }
  }

  # Flatten the allowed CIDRs, security groups, and ports for each resource
  # endpoint into a map of ingress rules.
  resource_endpoint_rules = merge([
    for name, endpoint in var.resource_endpoints : merge(
      {
        for rule in setproduct(range(length(endpoint.cidrs)), endpoint.ports) :
        "${name}/cidr/${rule[0]}:${rule[1]}" => {
          endpoint          = name
          cidr              = endpoint.cidrs[rule[0]]
          security_group_id = null
          port              = rule[1]
        }
      },
      {
        for rule in setproduct(range(length(endpoint.security_group_ids)), endpoint.ports) :
        "${name}/sg/${rule[0]}:${rule[1]}" => {
          endpoint          = name
          cidr              = null
          security_group_id = endpoint.security_group_ids[rule[0]]
          port              = rule[1]
        }
      }
    )
  ]...)
}
