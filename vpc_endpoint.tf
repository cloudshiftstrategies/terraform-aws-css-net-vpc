#vpc_endpoints.tf

#############################
# s3 endpoint

# Create an s3 gateway in the vpc if this is not a public vpc and create_s3_endpoint = true
resource "aws_vpc_endpoint" "s3gw" {
  count        = "${var.vpcType != "public" && var.create_s3_endpoint ? 1 : 0}"
  vpc_id       = "${aws_vpc.vpc.id}"
  service_name = "com.amazonaws.${var.region}.s3"
}

# Attach the s3 gateway to the main VPC route table
resource "aws_vpc_endpoint_route_table_association" "s3ep_assoc" {
  count           = "${var.vpcType != "public" && var.create_s3_endpoint ? 1 : 0}"
  route_table_id  = "${aws_vpc.vpc.main_route_table_id}"
  vpc_endpoint_id = "${aws_vpc_endpoint.s3gw.id}"
}

#############################
# ssm endpoints

# Create endpoints required for ssm if:
# this is not a public vpc and create_app_subnets = true AND create_ssm_endpoints = true
resource "aws_vpc_endpoint" "if_endpoints" {
  count             = "${var.vpcType != "public" && var.create_app_subnets && var.create_ssm_endpoints ? length(local.endpoints) : 0}"
  vpc_id            = "${aws_vpc.vpc.id}"
  service_name      = "com.amazonaws.${var.region}.${element(local.endpoints, count.index)}"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    "${aws_subnet.app_subnet.*.id}",
  ]

  security_group_ids = ["${aws_security_group.endpoint_sg.id}"]
}

# Create a security group for the endpoints we created any endpoints above if:
# this is not a public vpc and create_app_subnets = true AND create_ssm_endpoints = true
resource "aws_security_group" "endpoint_sg" {
  count       = "${var.vpcType != "public" && var.create_app_subnets && var.create_ssm_endpoints ? 1 : 0}"
  description = "Allow inbound tcp 443 traffic from VPC for vpc endpoints"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "${var.vpcCidr}",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = "${merge( local.default_tags, map (
    "Name", "sg-ssm-endpoints-${var.deptName}-${var.appName}-${var.envName}-${var.region}",
    "Ci", ""
  ))}"
}
