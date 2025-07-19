module "s3_example" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"
  bucket = "${local.vars.record_name}.${local.vars.domain_name}"
  force_destroy = true
  object_lock_enabled = true
  acl    = "private"
  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "AES256"
      }
    }
  }
  website = {
    index_document = "index.html"
    error_document = "error.html"
  }
  versioning = {
    enabled = true
  }
  attach_policy    = true
  policy           = data.aws_iam_policy_document.example_bucket_policy_document.json
}

data "aws_route53_zone" "example_route53_zone" {
  name         = local.vars.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "weqs_certificate" {
  provider = aws.east
  domain_name       = "${local.vars.record_name}.${local.vars.domain_name}"
  validation_method = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "route53_weqs_records_verification" {
  for_each = {
    for domain_verification_option in aws_acm_certificate.weqs_certificate.domain_validation_options : domain_verification_option.domain_name => {
      name   = domain_verification_option.resource_record_name
      record = domain_verification_option.resource_record_value
      type   = domain_verification_option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.example_route53_zone.zone_id
}


resource "aws_acm_certificate_validation" "weqs_certificate_validation" {
  provider = aws.east
  certificate_arn         = aws_acm_certificate.weqs_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_weqs_records_verification : record.fqdn]
}

data "aws_acm_certificate" "acm_admin_issued" {
  provider = aws.east
  domain   = "${local.vars.record_name}.${local.vars.domain_name}"
  statuses = ["ISSUED"]
  depends_on = [ aws_acm_certificate_validation.weqs_certificate_validation ]
}

module "example_cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.0"

  aliases = ["${local.vars.record_name}.${local.vars.domain_name}"]

  default_root_object = "index.html"

  create_origin_access_control = true

  origin_access_control = {
    s3_admin_oac = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3_admin_oac = {
      domain_name           = module.s3_example.s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_admin_oac"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_admin_oac"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["HEAD", "GET", "OPTIONS"]
    cached_methods  = ["HEAD", "GET"]
    compress        = true
    query_string    = false
  }

  custom_error_response = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  viewer_certificate = {
    acm_certificate_arn      = data.aws_acm_certificate.acm_admin_issued.id
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [module.s3_example]
}


resource "aws_route53_record" "example_records" {
  zone_id = data.aws_route53_zone.example_route53_zone.zone_id
  name    =  "${local.vars.record_name}.${local.vars.domain_name}" 
  type    = "A"

  alias {
    name                   = replace(module.example_cloudfront.cloudfront_distribution_domain_name, "/[.]$/", "")
    zone_id                = module.example_cloudfront.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
  depends_on = [module.example_cloudfront]
}