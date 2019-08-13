# output.tf

output "vpcId" {
  description = "VPC ID of the new VPC that was created"
  value       = "${aws_vpc.vpc.id}"
}

output "tgwId" {
  description = "TransitGateway Id"
  value       = "${data.terraform_remote_state.aws_dotc-infra-prd_net-transitgw-prd.tgw_ids[var.region]}"
}

output "webSubnetIds" {
  description = "Subnet IDs of the web subnets created"
  value       = "${aws_subnet.web_subnet.*.id}"
}

output "appSubnetIds" {
  description = "Subnet IDs of the app subnets created"
  value       = "${aws_subnet.app_subnet.*.id}"
}

output "dbSubnetIds" {
  description = "Subnet IDs of the db subnets created"
  value       = "${aws_subnet.database_subnet.*.id}"
}
