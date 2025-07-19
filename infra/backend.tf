terraform {
  backend "s3" {
    bucket = "myallstatefiles"
    key    = "appfront/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt        = true
  }
}
