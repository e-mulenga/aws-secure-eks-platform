data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix  = "${var.organization_name}-${var.environment}"
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  region       = data.aws_region.current.name
  cluster_name = "${local.name_prefix}-${var.cluster_name}"

  vpc_id = data.terraform_remote_state.landing_zone.outputs.vpc_id

  private_subnet_ids = data.terraform_remote_state.landing_zone.outputs.private_subnet_ids

  public_subnet_ids = data.terraform_remote_state.landing_zone.outputs.public_subnet_ids

  database_subnet_ids = data.terraform_remote_state.landing_zone.outputs.database_subnet_ids

  intra_subnet_ids = try(data.terraform_remote_state.landing_zone.outputs.intra_subnet_ids, []
  )
}

data "terraform_remote_state" "landing_zone" {

  backend = "s3"

  config = {

    bucket = "your-terraform-state-bucket"

    key = "landing-zone/dev/terraform.tfstate"

    region = "af-south-1"

  }

}
