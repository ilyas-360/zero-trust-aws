terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.security, aws.workload]
    }
  }
}

locals {
  boundary_document = jsondecode(file("${path.module}/../../../policies/iam/permission-boundaries.json"))
  boundary_policy = {
    for key, value in local.boundary_document : key => value if !startswith(key, "_")
  }
}

resource "aws_iam_policy" "workload_permission_boundary" {
  provider = aws.workload

  name        = "WorkloadPermissionBoundary"
  description = "Maximum permissions for the project's security-audit role in the workload account."
  policy      = jsonencode(local.boundary_policy)
}

# This role is intentionally a single, auditable example. The boundary is
# attached here; it is not automatically attached to every role in the account.
resource "aws_iam_role" "workload_security_read" {
  provider = aws.workload

  name                 = "WorkloadSecurityReadRole"
  description          = "Read-only security evidence role assumed by the Security account."
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.workload_permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecurityAccountOnly"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.security_account_id}:role/SecurityAssumeWorkloadReadRole"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalOrgID" = var.organization_id
        }
      }
    }]
  })

  tags = {
    Purpose = "security-audit"
  }
}

resource "aws_iam_role_policy" "workload_security_read" {
  provider = aws.workload

  name = "WorkloadSecurityReadOnly"
  role = aws_iam_role.workload_security_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudtrail:DescribeTrails",
        "cloudtrail:GetTrailStatus",
        "cloudtrail:LookupEvents",
        "config:Describe*",
        "config:Get*",
        "config:List*",
        "ec2:Describe*",
        "guardduty:Get*",
        "guardduty:List*",
        "securityhub:Describe*",
        "securityhub:Get*",
        "securityhub:List*"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "security_assume_workload_read" {
  provider = aws.security

  name                 = "SecurityAssumeWorkloadReadRole"
  description          = "Management-account operator role used to reach the workload audit role through the Security account. Enforce human MFA in IAM Identity Center or the upstream IdP."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManagementAccountOperators"
      Effect = "Allow"
      Principal = {
        AWS = var.management_operator_role_arn
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalOrgID" = var.organization_id
        }
      }
    }]
  })

  tags = {
    Purpose = "security-audit"
  }
}

resource "aws_iam_role_policy" "security_assume_workload_read" {
  provider = aws.security

  name = "AssumeWorkloadSecurityReadRole"
  role = aws_iam_role.security_assume_workload_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.workload_security_read.arn
    }]
  })
}
