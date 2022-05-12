terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.11.0"
      //noinspection HILUnresolvedReference
      configuration_aliases = [
        aws,
        aws.us
      ]
    }
  }
}
locals {
  app_name               = "${var.env_client}-${var.env_version}-Backend"
  pub_bucket             = lower("${var.env_client}-${var.env_version}-Public-Bucket")
  pub_bucket_arn         = "arn:aws:s3:::${local.pub_bucket}"
  eb_cname               = "eb.${var.domain_name}"
}
data "aws_caller_identity" "default" {}
//--------------------------------------------------------------------

# domain or subdomain
data "aws_route53_zone" "domain" {
  zone_id = var.zone_id
}

# s3 public bucket
// public bucket policy
data "aws_iam_policy_document" "public" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    effect  = "Deny"
    actions = [
      "s3:*"
    ]

    resources = [
      "${local.pub_bucket_arn}/*",
      local.pub_bucket_arn
    ]
    condition {
      test   = "Bool"
      values = [
        false
      ]
      variable = "aws:SecureTransport"
    }
    principals {
      identifiers = [
        "*"
      ]
      type = "*"
    }
  }

# ToDo: add cloudfront
#  statement {
#    sid     = "AllowCloudFront"
#    effect  = "Allow"
#    actions = [
#      "s3:GetObject",
#      "s3:ListBucket",
#      "s3:GetBucketLocation"
#    ]
#
#    resources = [
#      "${local.pub_bucket_arn}/*",
#      local.pub_bucket_arn
#    ]
#    principals {
#      identifiers = [
#        var.cloudfront_identity
#      ]
#      type = "AWS"
#    }
#  }

}
resource "aws_s3_bucket" "public" {
  bucket        = local.pub_bucket
  force_destroy = false

  tags = {
    Env = var.env_version
  }
}


resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.public.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

  #  depends_on = [
  #    aws_s3_bucket_policy.public
  #  ]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "public" {
  bucket = aws_s3_bucket.public.id
  versioning_configuration {
    status = "Enabled"
  }
}

# for drp
#resource "aws_s3_bucket_replication_configuration" "public" {
#  # Must have bucket versioning enabled first
#  depends_on = [aws_s3_bucket_versioning.public]
#
#  role   = aws_iam_role.backup_replication_role.arn
#  bucket = aws_s3_bucket.public.id
#
#  rule {
#    id     = "drp-replication"
#    status = "Enabled"
#    source_selection_criteria {
#      sse_kms_encrypted_objects {
#        status = "Enabled"
#      }
#    }
#
#    destination {
#      bucket        = local.bucket_drp_backup_arn
#      storage_class = "STANDARD"
#      encryption_configuration {
#        replica_kms_key_id = var.kms_arn
#      }
#    }
#    delete_marker_replication {
#      status = "Enabled"
#    }
#  }
#}

resource "aws_s3_bucket_cors_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  cors_rule {
    allowed_headers = [
      "*"
    ]
    allowed_methods = [
      "GET"
    ]
    allowed_origins = [
      "*"
    ]
    expose_headers = []
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  rule {
    id = "cleanOldVersions"
    abort_incomplete_multipart_upload { days_after_initiation = 1 }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    expiration {
      expired_object_delete_marker = true
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.public.id
  policy = data.aws_iam_policy_document.public.json
}
resource "aws_ssm_parameter" "bucket_public" {
  name        = "/${var.env_project}/${var.env_version}/BUCKET_PUBLIC"
  description = "ARN of the public bucket."
  type        = "String"
  value       = local.pub_bucket
  tags        = {
    Env = var.env_version
  }
}

# create EB



# cloudfront

# ses
