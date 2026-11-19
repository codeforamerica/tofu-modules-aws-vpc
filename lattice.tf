resource "aws_security_group" "resource_gateway" {
  for_each = var.resource_gateway == null ? toset([]) : toset(["this"])

  name_prefix = "${local.prefix}-resource-gateway-"
  description = "Controls traffic leaving the VPC Lattice resource gateway."
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, { Name = "${local.prefix}-resource-gateway" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "resource_gateway" {
  for_each = local.resource_gateway_rules

  security_group_id = aws_security_group.resource_gateway["this"].id
  description       = "Allow TCP traffic on port ${each.value.port} to ${each.value.cidr}."
  cidr_ipv4         = strcontains(each.value.cidr, ":") ? null : each.value.cidr
  cidr_ipv6         = strcontains(each.value.cidr, ":") ? each.value.cidr : null
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

resource "aws_vpclattice_resource_gateway" "this" {
  for_each = var.resource_gateway == null ? toset([]) : toset(["this"])

  name                   = local.prefix
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [aws_security_group.resource_gateway["this"].id]
  ip_address_type        = var.resource_gateway.ip_address_type
  ipv4_addresses_per_eni = var.resource_gateway.ipv4_addresses_per_eni

  tags = var.tags
}

resource "aws_security_group" "resource_endpoint" {
  for_each = var.resource_endpoints

  name_prefix = "${local.prefix}-${each.key}-"
  description = "Controls access to the ${each.key} resource endpoint."
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, { Name = "${local.prefix}-${each.key}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "resource_endpoint" {
  for_each = local.resource_endpoint_rules

  security_group_id            = aws_security_group.resource_endpoint[each.value.endpoint].id
  description                  = "Allow TCP traffic on port ${each.value.port} from ${coalesce(each.value.cidr, each.value.security_group_id)}."
  cidr_ipv4                    = each.value.cidr == null ? null : strcontains(each.value.cidr, ":") ? null : each.value.cidr
  cidr_ipv6                    = each.value.cidr == null ? null : strcontains(each.value.cidr, ":") ? each.value.cidr : null
  referenced_security_group_id = each.value.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_endpoint" "resource" {
  for_each = var.resource_endpoints

  vpc_id                     = module.vpc.vpc_id
  vpc_endpoint_type          = "Resource"
  resource_configuration_arn = each.value.resource_configuration_arn
  subnet_ids                 = module.vpc.private_subnets
  security_group_ids         = [aws_security_group.resource_endpoint[each.key].id]
  private_dns_enabled        = each.value.private_dns

  tags = merge(var.tags, { Name = "${local.prefix}-${each.key}" })
}
