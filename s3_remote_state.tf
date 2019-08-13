# s3_remote_state.tf

# The remote state of the workspace that deploys the transit gateways
data "terraform_remote_state" "aws_dotc-infra-prd_net-transitgw-prd" {
  backend = "s3"

  config {
    bucket = "dotc-terraform-states"
    key    = "aws_dotc-infra-prd_net-transitgw-prd"
  }
}
