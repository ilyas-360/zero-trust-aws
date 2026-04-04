# =============================================================================
# Module: logging
# =============================================================================
# Deploys immutable audit logging infrastructure:
#   - Organization CloudTrail (captures API calls across ALL accounts)
#   - S3 bucket in Logging account with deny-delete bucket policy
#   - CloudWatch log group for metric-based alerting
#   - VPC Flow Logs
#
# Design decision: The S3 bucket that receives CloudTrail logs lives in the
# Logging account, which is isolated — no inbound network connectivity and
# an SCP that denies s3:DeleteObject even from root. This creates two
# independent layers of protection for the audit trail:
#   1. SCP (organizational enforcement)
#   2. S3 bucket policy (resource-level enforcement)
# An attacker would need to compromise both the Logging account AND remove
# the SCP from the Management account to destroy logs.
# =============================================================================

# -----------------------------------------------------------------------------
# S3 bucket for CloudTrail logs — immutable by design
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "zero-trust-cloudtrail-logs-${var.logging_account_id}"
  force_destroy = false  # Terraform cannot delete this bucket even with destroy

  tags = {
    Purpose    = "immutable-audit-logs"
    Compliance = "cloudtrail-organization-trail"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"  # Versioning prevents overwrite attacks
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Block all public access — explicit, not just default
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: allow CloudTrail to write, deny all deletes including root
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        # CRITICAL: deny all deletes — this is the immutability guarantee
        # Combined with the deny-delete SCP, this creates two independent layers
        Sid       = "DenyAllDeletes"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket",
        ]
        Resource = [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*",
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Organization CloudTrail — captures all accounts, all regions
# -----------------------------------------------------------------------------

resource "aws_cloudtrail" "organization_trail" {
  name                          = "zero-trust-organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  include_global_service_events = true  # IAM, STS, Route53
  is_multi_region_trail         = true  # All regions, not just primary
  is_organization_trail         = true  # All accounts in the organization
  enable_log_file_validation    = true  # Detect tampered log files

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]  # Log all S3 object-level events
    }
  }

  tags = {
    Purpose = "organization-audit-trail"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for CloudTrail — enables metric-based alerting
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/organization-trail"
  retention_in_days = var.log_retention_days

  tags = {
    Purpose = "cloudtrail-logs"
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "CloudTrailCloudWatchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "CloudTrailCloudWatchPolicy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}
