variable "environment" {
  description = "Different environments for the project"
  type = map(object({
    project_name  = string
    region        = string
    domain_name   = string
    record_name    = string
  }))
}


variable "project_tags" {
  description = "Project tags to be attached to resources"
  type = object({
    project_name = string
    owner        = string
  })
}
