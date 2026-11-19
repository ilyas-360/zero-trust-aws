output "workload_security_read_role_arn" {
  description = "Role ARN assumed by the Security account for read-only workload security evidence."
  value       = aws_iam_role.workload_security_read.arn
}

output "security_assume_workload_role_arn" {
  description = "Security account role that authorized operators assume before reading workload evidence."
  value       = aws_iam_role.security_assume_workload_read.arn
}
