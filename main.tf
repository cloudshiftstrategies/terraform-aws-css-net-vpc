# main.tf

# The remote state of the workspace that deploys the transit gateways
data "terraform_remote_state" "aws_dotc-infra-prd_net-transitgw-prd" {
  backend = "atlas"

  config {
    name = "DOTCommInfrastructure/aws_dotc-infra-prd_net-transitgw-prd"
  }
}
