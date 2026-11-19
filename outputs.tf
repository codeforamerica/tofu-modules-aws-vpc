output "availability_zones" {
  value       = module.vpc.azs
  description = "The availability zones in which the VPC subnets are created."
}

output "endpoint_ids" {
  value       = module.endpoints.endpoints
  description = "Map of created VPC endpoints keyed by service name."
}

output "endpoints_security_group_id" {
  value       = module.endpoints.security_group_id
  description = <<-EOT
    ID of the security group attached to the interface VPC endpoints.
    EOT
}

output "peer_ids" {
  value       = [for peer in aws_vpc_peering_connection.peer : peer.id]
  description = "The IDs of any created VPC peering connections."
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "The IDs of the private subnets in the VPC."
}

output "private_subnets_cidr_blocks" {
  value       = module.vpc.private_subnets_cidr_blocks
  description = "The CIDR blocks of the private subnets in the VPC."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "The IDs of the public subnets in the VPC."
}

output "public_subnets_cidr_blocks" {
  value       = module.vpc.public_subnets_cidr_blocks
  description = "The CIDR blocks of the public subnets in the VPC."
}

output "resource_endpoints" {
  value = {
    for name, endpoint in aws_vpc_endpoint.resource : name => {
      id                = endpoint.id
      security_group_id = aws_security_group.resource_endpoint[name].id
    }
  }
  description = <<-EOT
    Map of created VPC Lattice resource endpoints keyed by name, each with its
    ID and security group ID.
    EOT
}

output "resource_gateway" {
  value = one([
    for gateway in aws_vpclattice_resource_gateway.this : {
      arn               = gateway.arn
      id                = gateway.id
      security_group_id = aws_security_group.resource_gateway["this"].id
    }
  ])
  description = <<-EOT
    The VPC Lattice resource gateway, if created, with its ARN, ID, and
    security group ID.
    EOT
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC."
}
