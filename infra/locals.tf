locals {
  env = terraform.workspace
  vars  = var.environment[local.env]
  tags = merge(var.project_tags, { ENV = local.env })
  s3_origin_id = "${local.vars.project_name}-origin-admin-${local.env}"
}
