# Compliance Policies (Rego / OPA / Conftest)

Policy-as-Code library covering both GCP and AWS resources, evaluated against `terraform show -json` plan output before apply. Each control has a GCP-typed and an AWS-typed implementation, sharing a control ID but matching different resource types and, in some cases, different plan JSON sections. Every policy includes structured `# METADATA` annotations; the GCP policies additionally have `_test.rego` unit suites with passing and failing fixtures.

| Control | Cloud | File | Severity | Enforces | Remediation |
|---|---|---|---|---|---|
| SC-28 | GCP | `sc28_encryption.rego` | High | Every `google_storage_bucket` has a customer-managed encryption key (CMEK) via an `encryption { default_kms_key_name }` block. | Add an `encryption { default_kms_key_name = ... }` block referencing a `google_kms_crypto_key` you control. |
| SC-28 | AWS | `sc28_encryption_aws.rego` | High | Every `aws_s3_bucket` has a matching `aws_s3_bucket_server_side_encryption_configuration` referencing it. | Add `aws_s3_bucket_server_side_encryption_configuration { bucket = aws_s3_bucket.<name>.id ... }`. |
| AC-3 | GCP | `ac3_no_public.rego` | High | Buckets have `uniform_bucket_level_access=true` and `public_access_prevention="enforced"`. Firewalls do not expose management ports (22, 3389) to `0.0.0.0/0` or `*`. | Set the two bucket flags above. Narrow firewall `source_ranges`, or remove the rule. |
| AC-3 | AWS | `ac3_no_public_aws.rego` | Critical | Every `aws_s3_bucket` has an `aws_s3_bucket_public_access_block` referencing it, with all four flags (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) set `true`. | Add the public access block resource with all four flags `true`. Partial configuration (some flags true, others false or missing) still fails. |
| CM-6 | GCP | `cm6_required_tags.rego` | Medium | Every taggable resource (`google_storage_bucket`, `google_compute_instance`, `google_compute_disk`) carries all four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. | Add the missing labels to the resource. |
| CM-6 | AWS | `cm6_required_tags_aws.rego` | Medium | Every taggable resource (`aws_s3_bucket`, `aws_dynamodb_table`, `aws_lambda_function`, `aws_kms_key`, `aws_cloudtrail`) carries all four required tags: `Project`, `Environment`, `ManagedBy`, `ComplianceScope`, whether set directly or via provider `default_tags` (merged into `tags_all`). | Add the missing tags, or set them once via provider `default_tags`. |

## Running the GCP unit test suite

```bash
opa test -v policies/
```

## Evaluating against a real plan (GCP)

```bash
opa eval -d policies -i terraform/plan.json data.compliance.sc28.deny --format=pretty
opa eval -d policies -i terraform/plan.json data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i terraform/plan.json data.compliance.cm6.deny  --format=pretty
```

## Evaluating against a real plan (AWS, via Conftest)

```bash
conftest test --policy policies --namespace compliance.sc28_aws plan.json
conftest test --policy policies --namespace compliance.ac3_aws  plan.json
conftest test --policy policies --namespace compliance.cm6_aws  plan.json
```

## Running the full gate (all four AWS-relevant namespaces, one command)

```bash
./scripts/policy-gate.sh --workspace <path-to-terraform-workspace>
```

Writes a JSON evidence artifact to `evidence/lab-3-4/conftest-results.json` and exits non-zero if any namespace has a violation. This is the script Lab 4.3's CI workflow calls directly.

## Design notes

- **Plan-time evaluation only.** Policies never touch live infrastructure or Terraform state — they operate exclusively on `terraform show -json` output, so violations are caught before anything is created.
- **Control IDs are portable across clouds; resource-type matches are not.** A GCP-typed rule run against an AWS plan (or vice versa) reports a vacuous pass — it finds zero matching resources, not zero violations. Each control therefore has one implementation per cloud, sharing a control ID but never sharing resource-type logic.
- **AWS existence checks use `configuration`, not `planned_values`, for anything wired by reference.** Bucket names with a `random_id` suffix are unresolved ("known after apply") at plan time, so both SC-28 and AC-3 (AWS) match on `expressions.<arg>.references` — the symbolic HCL wiring — rather than comparing literal resource values.
- **AC-3 (AWS) is stricter than a bare existence check.** It requires the public access block resource to exist *and* all four boolean flags to be `true`; a partially configured block still fails.
- **CM-6 (AWS) prefers `tags_all` over `tags`**, falling back to plain `tags` if the provider has no `default_tags` block, and to an explicit empty set if a resource has neither — never leaving the check `undefined`.
- **Every deny message includes the resource address, control ID, and remediation text**, so a developer can self-remediate without opening a GRC ticket.
- **Module-wrapped resources are covered via `child_modules[]` recursion** in every rule that walks `planned_values`, matching the reusable-module pattern established in Lab 2.4.
