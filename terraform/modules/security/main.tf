terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.security]
    }
  }
}

resource "aws_guardduty_organization_admin_account" "security" {
  provider = aws.management
  count    = var.enable_guardduty ? 1 : 0

  admin_account_id = var.security_account_id
}

resource "aws_guardduty_detector" "security" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  enable = true
}

resource "aws_guardduty_organization_configuration" "security" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  detector_id                        = aws_guardduty_detector.security[0].id
  auto_enable_organization_members   = "ALL"
  depends_on                         = [aws_guardduty_organization_admin_account.security]
}

resource "aws_securityhub_organization_admin_account" "security" {
  provider = aws.management
  count    = var.enable_securityhub ? 1 : 0

  admin_account_id = var.security_account_id
  depends_on       = [aws_securityhub_account.security]
}

resource "aws_securityhub_account" "security" {
  provider = aws.security
  count    = var.enable_securityhub ? 1 : 0
}

resource "aws_securityhub_organization_configuration" "security" {
  provider = aws.security
  count    = var.enable_securityhub ? 1 : 0

  auto_enable = true
  depends_on  = [aws_securityhub_organization_admin_account.security, aws_securityhub_account.security]
}

resource "aws_securityhub_finding_aggregator" "all_regions" {
  provider = aws.security
  count    = var.enable_securityhub ? 1 : 0

  linking_mode = "ALL_REGIONS"
  depends_on   = [aws_securityhub_account.security]
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  provider = aws.security
  count    = var.enable_securityhub ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.security]
}

resource "aws_securityhub_standards_subscription" "cis_1_4" {
  provider = aws.security
  count    = var.enable_securityhub ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.security]
}

resource "aws_sns_topic" "security_alerts" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  name = "zero-trust-security-alerts"
}

resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  name        = "guardduty-high-severity-findings"
  description = "Matches GuardDuty findings with severity 7 or higher in this Region."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_sns_topic_policy" "security_alerts" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  arn = aws_sns_topic.security_alerts[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgePublishFromGuardDutyRule"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.security_alerts[0].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.guardduty_high_severity[0].arn
        }
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "security_alerts" {
  provider = aws.security
  count    = var.enable_guardduty ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_high_severity[0].name
  target_id = "SendGuardDutyFindingToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

  depends_on = [aws_sns_topic_policy.security_alerts]
}

resource "aws_sns_topic_subscription" "alert_email" {
  provider = aws.security
  count    = var.enable_guardduty && var.alert_email_address != null && trimspace(var.alert_email_address) != "" ? 1 : 0

  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email_address
}
