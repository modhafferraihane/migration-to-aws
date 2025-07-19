environment = {
  dev = {
    project_name = "migration-to-aws"
    region       = "us-east-1"
    domain_name  = "eksops.site"
    record_name  = "dev"
  }
  # prod = {
  #   project_name  = ""
  #   region        = ""
  #   record_name   = "admin"

  # }
}

project_tags = {
  project_name = "migration-to-aws"
  owner        = "raihane"
}
