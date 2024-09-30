provider "aws" {
  default_tags {
    tags = {
      Environment = "github"
      Owner       = var.github_owner
      Repository  = var.github_repository
    }
  }
}

provider "github" {
  owner = var.github_owner
}
