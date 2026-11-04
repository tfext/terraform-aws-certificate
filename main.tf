terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = [aws.east]
    }
  }
}

data "aws_region" "current" {}

data "aws_route53_zone" "domain" {
  count = var.zone_id == null && var.manage_dns ? 1 : 0
  name  = coalesce(var.zone, var.domain)
}

locals {
  zone_id     = var.zone_id != null ? var.zone_id : try(data.aws_route53_zone.domain.0.zone_id, null)
  domain_name = var.wildcard ? "*.${var.domain}" : var.domain
  alt_names   = var.wildcard ? [var.domain] : []

  # A second certificate is only needed when the main provider isn't us-east-1
  separate_east = data.aws_region.current.region != "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  domain_name               = local.domain_name
  validation_method         = "DNS"
  subject_alternative_names = local.alt_names
}

resource "aws_acm_certificate" "cert_east" {
  count = local.separate_east ? 1 : 0

  provider                  = aws.east
  domain_name               = local.domain_name
  validation_method         = "DNS"
  subject_alternative_names = local.alt_names
}

locals {
  # Cert will list duplicate records for wildcards
  validation_records = var.validate ? merge([
    for dvo in setunion(aws_acm_certificate.cert.domain_validation_options, aws_acm_certificate.cert_east[*].domain_validation_options...)
    : { "${dvo.resource_record_name}" = dvo }
  ]...) : {}

  # Every certificate's validation records, deduplicated, for adding to DNS by hand
  distinct_validation_records = distinct([
    for dvo in setunion(aws_acm_certificate.cert.domain_validation_options, aws_acm_certificate.cert_east[*].domain_validation_options...) : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ])
}

moved {
  from = aws_acm_certificate.cert_east
  to   = aws_acm_certificate.cert_east[0]
}

resource "aws_route53_record" "domain_validation" {
  for_each = var.manage_dns ? local.validation_records : {}

  allow_overwrite = true
  name            = each.key
  records         = [each.value.resource_record_value]
  ttl             = 60
  type            = each.value.resource_record_type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  count = var.wait_for_validation ? 1 : 0

  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = var.manage_dns && var.validate ? [for record in aws_route53_record.domain_validation : record.fqdn] : null
}

resource "aws_acm_certificate_validation" "cert_east" {
  count = var.wait_for_validation && local.separate_east ? 1 : 0

  provider                = aws.east
  certificate_arn         = aws_acm_certificate.cert_east[0].arn
  validation_record_fqdns = var.manage_dns && var.validate ? [for record in aws_route53_record.domain_validation : record.fqdn] : null
}
