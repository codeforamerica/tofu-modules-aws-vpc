variable "additional_gateway_endpoints" {
  type        = set(string)
  description = <<-EOT
    Gateway endpoint service names to create in addition to the s3 default.
    EOT
  default     = []
}

variable "additional_interface_endpoints" {
  type        = set(string)
  description = <<-EOT
    Interface endpoint service names to create in addition to the defaults
    EOT
  default     = []
}

variable "cidr" {
  type        = string
  description = "IPv4 CIDR block for the VPC."
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "dev"
}

variable "log_retention_period" {
  type        = number
  default     = 30
  description = "Retention period for flow logs, in days."
}

variable "logging_key_id" {
  type        = string
  description = "KMS key ID for encrypting logs."
}

variable "peers" {
  type = map(object({
    account_id = string
    cidr       = string
    region     = string
    vpc_id     = string
  }))

  description = "List of VPC peering connections."
  default     = {}
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR blocks."
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR blocks."
}

variable "resource_endpoints" {
  type = map(object({
    resource_configuration_arn = string
    ports                      = set(number)
    cidrs                      = optional(list(string), [])
    security_group_ids         = optional(list(string), [])
    private_dns                = optional(bool, true)
  }))

  description = <<-EOT
    VPC Lattice resource endpoints to create, keyed by name. Ingress to each
    endpoint is allowed only on the listed ports from the listed CIDRs and
    security groups. Private DNS requires that the resource configuration has a
    verified custom domain name; disable it if it doesn't.
    EOT
  default     = {}

  validation {
    condition = alltrue([
      for endpoint in values(var.resource_endpoints) : length(endpoint.ports) > 0
    ])
    error_message = "Each resource endpoint must allow at least one port."
  }

  validation {
    condition = alltrue([
      for endpoint in values(var.resource_endpoints) :
      length(endpoint.cidrs) + length(endpoint.security_group_ids) > 0
    ])
    error_message = "Each resource endpoint must allow at least one CIDR or security group."
  }
}

variable "resource_gateway" {
  type = object({
    ports                  = set(number)
    cidrs                  = list(string)
    ip_address_type        = optional(string, "IPV4")
    ipv4_addresses_per_eni = optional(number)
  })

  description = <<-EOT
    Create a VPC Lattice resource gateway in the private subnets. Egress from
    the gateway is limited to the given ports and CIDRs. Disabled when `null`.
    EOT
  default     = null

  validation {
    condition     = var.resource_gateway == null || length(var.resource_gateway.ports) > 0
    error_message = "The resource gateway must allow at least one port."
  }

  validation {
    condition     = var.resource_gateway == null || length(var.resource_gateway.cidrs) > 0
    error_message = "The resource gateway must allow at least one CIDR."
  }

  validation {
    condition = var.resource_gateway == null || contains(
      ["IPV4", "IPV6", "DUALSTACK"], var.resource_gateway.ip_address_type
    )
    error_message = "The resource gateway's ip_address_type must be IPV4, IPV6, or DUALSTACK."
  }

  validation {
    condition = (
      var.resource_gateway == null ||
      var.resource_gateway.ipv4_addresses_per_eni == null ||
      var.resource_gateway.ip_address_type != "IPV6"
    )
    error_message = "The resource gateway's ipv4_addresses_per_eni can't be set when ip_address_type is IPV6."
  }
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "Enable to deploy one NAT gateway rather than one per subnet. Cheaper, but is not highly available."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
