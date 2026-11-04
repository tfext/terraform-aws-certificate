output "arn" {
  value       = aws_acm_certificate.cert.arn
  description = "Certificate ARN"
}

output "arn-east" {
  value       = local.separate_east ? aws_acm_certificate.cert_east[0].arn : aws_acm_certificate.cert.arn
  description = "Certificate ARN for us-east-1 (the same as arn when the provider's region is us-east-1)"
}

output "validation_records" {
  value       = local.distinct_validation_records
  description = "Distinct DNS validation records ({ name, type, value }) for adding by hand when manage_dns is false"
}
