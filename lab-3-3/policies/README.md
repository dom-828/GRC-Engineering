# Compliance Policies (Rego / OPA)

Policy-as-Code library for GCP resources, evaluated against `terraform plan -json` output before apply. Each policy maps to a NIST 800-53 control and includes structured `# METADATA` annotations plus a `_test.rego` suite with passing and failing fixtures.

| Control | File | Severity | Enforces | Remediation |
|---|---|---|---|---|
| SC-28 | `sc28_encryption.rego` | High | Every `google_storage_bucket` has a customer-managed encryption key (CMEK) configured via an `encryption { default_kms_key_name }` block. | Add an `encryption { default_kms_key_name = ... }` block referencing a `google_kms_crypto_key` you control. |
| AC-3 | `ac3_no_public.rego` | High | Buckets have `uniform_bucket_level_access=true` and `public_access_prevention="enforced"`. Firewalls do not expose management ports (22, 3389) to `0.0.0.0/0` or `*`. | Set the two bucket flags above. Narrow firewall `source_ranges` away from public CIDR ranges, or remove the rule. |
| CM-6 | `cm6_required_tags.rego` | Medium | Every taggable resource (`google_storage_bucket`, `google_compute_instance`, `google_compute_disk`) carries all four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. | Add the missing labels to the resource. |

## Running the suite

```bash
opa test -v policies/
```

## Evaluating against a real plan

```bash
opa eval -d policies -i terraform/plan.json data.compliance.sc28.deny --format=pretty
opa eval -d policies -i terraform/plan.json data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i terraform/plan.json data.compliance.cm6.deny  --format=pretty
```

Each policy operates independently on `input.planned_values.root_module.resources` (and `child_modules[]` for module-wrapped resources), so any of the three can be evaluated in isolation or combined into a single CI/CD gate.

## Design notes

- **Plan-time evaluation only.** Policies never touch live infrastructure or Terraform state — they operate exclusively on `terraform plan -json` output, so violations are caught before anything is created.
- **CMEK check is structural, not value-based.** `sc28_encryption.rego` checks for the *presence* of a non-empty `encryption` block rather than a resolved key value, because KMS key references are unresolved ("known after apply") at plan time.
- **Every deny message includes the resource address and control ID**, so a developer can self-remediate without opening a GRC ticket.
