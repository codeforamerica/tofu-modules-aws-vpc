terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      version = ">= 6.16"
      source  = "hashicorp/aws"
    }
  }
}
