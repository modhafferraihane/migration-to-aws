terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=6.0.0"
    }
  }
}

provider "aws" {
  region = local.vars.region
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
  default_tags {
    tags = local.tags
  }
}