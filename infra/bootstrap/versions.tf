terraform {
  required_version = "~> 1.8.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0.0"
    }
  }
}
