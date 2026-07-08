\# compliant-gcs-bucket



A reusable Terraform module that provisions a GCS bucket with hardcoded, non-overridable compliance controls. Consumers supply business-relevant inputs (project, environment, retention, naming); the module enforces security and audit posture regardless of what the consumer requests.



\## Controls Implemented



| NIST 800-53 Control | Family | Enforcement |

|---|---|---|

| \*\*SC-12\*\* | Cryptographic Key Establishment and Management | Module provisions and owns a dedicated Cloud KMS keyring and crypto key — encryption is not left to a Google-managed default key. |

| \*\*SC-13\*\* | Cryptographic Protection | Bucket objects are encrypted using a customer-managed key (CMEK), AES-256, rather than platform-default encryption. |

| \*\*SC-28\*\* | Protection of Information at Rest | `encryption.default\_kms\_key\_name` binds the bucket to the CMEK; all objects are encrypted at rest under keys the consumer cannot bypass or disable. |

| \*\*AU-11\*\* | Audit Record Retention | Object versioning is always enabled, and a locked-duration retention policy (minimum 365 days in production, enforced via variable validation) prevents deletion or overwrite before the retention period expires. |

| \*\*CM-6\*\* | Configuration Settings | Four compliance labels (`project`, `environment`, `managed\_by`, `compliance\_scope`) are merged onto every bucket and cannot be suppressed by consumer-supplied labels. Uniform bucket-level access and public access prevention are hardcoded, not configurable. |



\## Usage



```hcl

module "data\_bucket" {

&#x20; source = "../../modules/compliant-gcs-bucket"



&#x20; gcp\_project        = "your-project-id"

&#x20; project\_label      = "your-label"

&#x20; environment         = "dev"

&#x20; retention\_days     = 30

&#x20; bucket\_name\_suffix = "unique-suffix"

}

```



\## Outputs



\- `bucket\_url`, `bucket\_self\_link` — bucket identifiers

\- `kms\_key\_id` — the CMEK protecting this bucket

\- `compliance\_attestation` — machine-readable confirmation of the controls above, read live from the created resources (not just echoed from input)



\## Design Note



Compliance-relevant settings live in `main.tf` and are not exposed as variables. Only `variables.tf` is user-configurable, and each customizable input carries validation rules — most notably, `retention\_days` is cross-validated against `environment`, refusing to `plan` (not just `apply`) a production bucket with sub-365-day retention.

