\# compliant-s3



This module enforces SC-28, AU-3, AU-6, CM-6, and AC-3 on a single S3 bucket. 

It provisions a primary data bucket with AES-256 server-side encryption, versioning, 

and a full public access block, alongside a dedicated log bucket that receives S3 

server access logs. All taggable resources automatically inherit four required 

compliance tags (Project, Environment, ManagedBy, ComplianceScope) via the 

provider's default\_tags configuration. Evidence of deployed configuration is 

captured as machine-readable JSON in evidence/lab-2-3/.

