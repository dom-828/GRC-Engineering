## Lab 4.4: Evidence Management & Chain of Custody (AWS)

This lab closes the loop between the CI/CD pipeline (Lab 4.3) and the immutable
evidence vault (Lab 2.5) using keyless Cosign signing via GitHub OIDC. Each PR
run now produces a signed, timestamped, immutably-stored evidence bundle that
can be independently verified without trusting the AWS account holder.

### Chain of Custody Properties

| Property | Proving Artifact | Mechanism |
|---|---|---|
| **Authenticity** | `evidence-<run>.tar.gz.sig.bundle` | Cosign keyless signature, issued via GitHub OIDC → Sigstore Fulcio short-lived certificate. Proves the bundle was produced by this exact repo/workflow, not forged by an AWS-account-privileged actor. |
| **Integrity** | `evidence-<run>.tar.gz.sha256` | SHA-256 hash computed at signing time in CI, recomputed independently by `verify-evidence.sh` at verification time. Any single-byte change produces a completely different hash. |
| **Timeliness** | Sigstore Rekor transparency log entry (embedded in `.sig.bundle`) | Public, append-only log timestamps the signature at creation. Independent of AWS account clock or control. |
| **Completeness** | `if: always()` on the sign/upload workflow step | Evidence is captured even when the policy gate (Conftest/tfsec) fails, preserving the full record of what was tested and what happened — not just successful runs. |
| **Preservation** | S3 Object Lock retention (checked live via `get-object-retention`) | Enforced independently of the signature; confirms the bucket still guarantees immutability at verification time, not just at upload time. |

### Verification

Run `scripts/verify-evidence.sh <run_id>` with `EVIDENCE_VAULT` set to the
vault bucket name. The script performs three independent checks — integrity,
authenticity/timestamp, and preservation — and reports `CHAIN INTACT` only if
all three pass.

Verified run: `29836549268`

### Known Limitations

- `verify-evidence.sh` uses `--certificate-identity-regexp '.*'`, which
  accepts any certificate from the correct OIDC issuer rather than matching
  this repo's exact workflow subject. A production deployment would tighten
  this to the specific expected identity pattern.
- Lab vault uses GOVERNANCE mode with 1-day retention (cost/lab-scope
  tradeoff); production deployments would use COMPLIANCE mode with
  longer retention.
- The tamper test (Step 5 of the lab) was understood conceptually but not
  executed as a live demonstration in this session.
