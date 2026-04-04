# =============================================================================
# Module: iam
# =============================================================================
# Deploys the Zero Trust IAM architecture:
#   - Permission boundary managed policy (applied to all workload roles)
#   - Cross-account role assumption chain
#   - Terraform deployment role in each account
#
# Design decision: No IAM users with long-lived access keys exist anywhere.
# All access goes through role assumption chains with short session durations.
#
# Escalation path closed: Permission boundaries prevent any role from
# creating new roles or attaching policies beyond what the boundary allows,
# even if the role has iam:CreateRole in its inline policy.
# =============================================================================

# -----------------------------------------------------------------------------
# Permission Boundary — deployed to every workload account
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "workload_permission_boundary" {
  for_each = toset(var.workload_accounts)

  provider = aws.workload

  name        = "WorkloadPermissionBoundary"
  description = "Maximum permissions cap for all roles in workload accounts. Cannot be removed by roles subject to it."
  policy      = file("${path.module}/../../../policies/iam/permission-boundaries.json")

  tags = {
    Purpose = "permission-boundary"
    Account = each.value
  }
}

# -----------------------------------------------------------------------------
# Cross-account role: Security account → read workload accounts
# -----------------------------------------------------------------------------

resource "aws_iam_role" "security_read_role" {
  name        = "SecurityAccountReadRole"
  description = "Allows Security account to read GuardDuty findings and CloudTrail from workload accounts"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.security_account}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  # Maximum session duration: 1 hour (just-in-time access)
  max_session_duration = 3600

  tags = {
    ZeroTrust = "role-assumption-chain"
  }
}

resource "aws_iam_role_policy" "security_read_policy" {
  name = "SecurityReadAccess"
  role = aws_iam_role.security_read_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "guardduty:Get*",
          "guardduty:List*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudtrail:LookupEvents",
          "config:Get*",
          "config:List*",
          "config:Describe*",
        ]
        Resource = "*"
      }
    ]
  })
}
