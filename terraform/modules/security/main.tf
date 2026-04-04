# =============================================================================
# Module: security
# =============================================================================
# Deploys centralized threat detection and security posture management:
#   - GuardDuty with delegated admin in Security account
#   - Security Hub aggregating findings from all accounts
#   - EventBridge rules for automated alerting
#
# Design decision: GuardDuty and Security Hub are administered from the
# Security account, not the Management account. This means even a compromise
# of the Management account cannot easily suppress findings — the Security
# account operates independently.
#
# Critical property: findings from workload accounts aggregate to the
# Security account automatically. A compromised workload account cannot
# delete or suppress its own GuardDuty findings because those findings
# are owned by the Security account.
# =============================================================================

# -----------------------------------------------------------------------------
# GuardDuty — enabled in Security account as delegated admin
# -----------------------------------------------------------------------------

resource "aws_guardduty_detector" "security_account" {
  enable = true

  datasources {
    s3_logs {
      enable = true  # Detect credential misuse via S3 API calls
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Purpose = "centralized-threat-detection"
  }
}

# Delegate GuardDuty administration to Security account
resource "aws_guardduty_organization_admin_account" "security" {
  admin_account_id = var.security_account_id
}

# Auto-enable GuardDuty for all new accounts joining the organization
resource "aws_guardduty_organization_configuration" "main" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.security_account.id

  datasources {
    s3_logs {
      auto_enable = true
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Security Hub — aggregated findings dashboard
# -----------------------------------------------------------------------------

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_organization_admin_account" "security" {
  admin_account_id = var.security_account_id
  depends_on       = [aws_securityhub_account.main]
}

# Enable key security standards
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.main]
}

# -----------------------------------------------------------------------------
# EventBridge: Alert on HIGH/CRITICAL GuardDuty findings
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "guardduty-high-severity-findings"
  description = "Triggers on GuardDuty findings with severity >= 7 (HIGH or CRITICAL)"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns_alert" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

resource "aws_sns_topic" "security_alerts" {
  name = "zero-trust-security-alerts"

  tags = {
    Purpose = "guardduty-alerting"
  }
}
