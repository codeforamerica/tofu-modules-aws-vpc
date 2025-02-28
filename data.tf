data "aws_availability_zones" "available" {
  state = "available"
}

# VPC endpoints don't have load balancers in every availability zone, so we need
# to lookup the supported availability zones and use them to filter our subnets.
data "aws_vpc_endpoint_service" "services" {
  for_each = local.interface_endpoint_services

  service = each.value
}

data "aws_subnets" "endpoints" {
  for_each = data.aws_vpc_endpoint_service.services

  filter {
    name   = "subnet-id"
    values = module.vpc.private_subnets
  }

  filter {
    name   = "availability-zone"
    values = each.value.availability_zones
  }
}
