data "aws_iam_policy_document" "example_bucket_policy_document" {
  statement {
    sid     = "PublicReadGetObject"
    actions = ["s3:GetObject", "s3:DeleteObject","s3:PutObject","s3:PutObjectAcl","s3:ListBucket"]
    effect  = "Allow"
    resources = ["arn:aws:s3:::${local.vars.record_name}.${local.vars.domain_name}/*","arn:aws:s3:::${local.vars.record_name}.${local.vars.domain_name}"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
