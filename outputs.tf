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

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC."
}
