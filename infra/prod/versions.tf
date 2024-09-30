terraform {
  required_version = "1.8.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69.0"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "~> 1.23.0"
    }
  }
}
