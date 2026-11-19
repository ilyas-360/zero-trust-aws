terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.logging]
    }
  }
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  provider      = aws.logging
  bucket        = var.cloudtrail_bucket_name
  force_destroy = false

  tags = {
    Purpose = "organization-cloudtrail-logs"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.management_account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudtrail:*:${var.management_account_id}:trail/zero-trust-organization-trail"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailOrgWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${var.organization_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceAccount" = var.management_account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudtrail:*:${var.management_account_id}:trail/zero-trust-organization-trail"
          }
        }
      },
      {
        Sid       = "DenyCloudTrailObjectDeletion"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:DeleteBucket"]
        Resource  = [aws_s3_bucket.cloudtrail_logs.arn, "${aws_s3_bucket.cloudtrail_logs.arn}/*"]
      }
    ]
  })
}

# Organization trails are managed from the Organizations management account.
resource "aws_cloudtrail" "organization" {
  provider = aws.management

  name                          = "zero-trust-organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    dynamic "data_resource" {
      for_each = length(var.s3_data_event_arns) > 0 ? [var.s3_data_event_arns] : []
      content {
        type   = "AWS::S3::Object"
        values = data_resource.value
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs, aws_s3_bucket_versioning.cloudtrail_logs, aws_s3_bucket_server_side_encryption_configuration.cloudtrail_logs]

  tags = {
    Purpose = "organization-audit-trail"
  }
}
