terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "REPLACE-ME-prod-terraform-state"
    key          = "eks-platform/prod/terraform.tfstate"
    region       = "af-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
