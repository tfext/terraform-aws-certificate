# terraform-aws-certificate

Request a DNS-validated ACM certificate in the main provider's region and in
`us-east-1` (for CloudFront and other global services).

```hcl
module "certificate" {
  source = "github.com/tfext/terraform-aws-certificate"

  domain   = "example.com"
  wildcard = true

  providers = {
    aws      = aws
    aws.east = aws.east
  }
}
```

The `aws.east` provider must target `us-east-1`. When the main provider's
region is also `us-east-1`, only one certificate is requested, and `arn-east`
returns the same ARN as `arn`.

## DNS validation

With `manage_dns = true` (the default), the module looks up the Route53 zone
(`zone_id`, else `zone`, else `domain`) and creates the validation records.
The records are keyed by values ACM only knows after the certificate exists,
so the first apply needs `validate = false`.

With `manage_dns = false`, no Route53 zone or records are touched. Add the
records from the `validation_records` output to your DNS provider by hand.

Set `wait_for_validation = true` to make an apply wait until the certificate is
issued. With `manage_dns = false`, apply once with it `false`, add the records,
then apply again with it `true`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `domain` | `string` | required | Domain to create the certificate for |
| `wildcard` | `bool` | `true` | Request `*.domain`, with `domain` as an alternative name |
| `zone` | `string` | `null` | Route53 zone for the validation records (defaults to `domain`) |
| `zone_id` | `string` | `null` | Explicit Route53 zone ID (exclusive with `zone`) |
| `validate` | `bool` | `true` | Create the Route53 validation records. Set to `false` for the first run |
| `manage_dns` | `bool` | `true` | Look up the Route53 zone and create the validation records. `false` skips both |
| `wait_for_validation` | `bool` | `false` | Wait during apply until the certificate is issued |

## Outputs

| Name | Description |
|---|---|
| `arn` | Certificate ARN in the main provider's region |
| `arn-east` | Certificate ARN in `us-east-1` |
| `validation_records` | Distinct `{ name, type, value }` validation records |
