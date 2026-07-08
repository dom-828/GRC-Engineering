# consumers/prod/main.tf
module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "project-f4826bb5-2e35-40d9-90d"
  project_label      = "cgep-lab"
  environment        = "prod"
  retention_days     = 365
  bucket_name_suffix = "prod-data-001"
}