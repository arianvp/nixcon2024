provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "global"
    }
  }
}

provider "github" {
  owner = var.github_owner
}


