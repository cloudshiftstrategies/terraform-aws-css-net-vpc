# vpc.tf
# VPC and subnets for use with an application

##################################
# VPC

# The VPC for this application
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpcCidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = "${merge( local.default_tags, map (
    "Name", "vpc-${var.deptName}-${var.appName}-${var.envName}-${var.vpcType}-${var.region}",
    "Ci", ""
  ))}"
}

# The the default route table for VPC so that we can add tags to it
resource "aws_default_route_table" "vpc_default_routetable" {
  default_route_table_id = "${aws_vpc.vpc.main_route_table_id}"

  tags = "${merge( local.default_tags, map (
    "Name", "rt-vpc-${var.deptName}-${var.appName}-${var.envName}-${var.region}",
    "Ci", ""
  ))}"
}

# Create DHCP Options for private and mixed VPCs
resource "aws_vpc_dhcp_options" "dhcp_opts" {
  count               = "${var.vpcType != "public" && var.create_dhcp_opts ? 1 : 0}"
  domain_name         = "${var.dnsSuffix}"
  domain_name_servers = "${var.dnsServers}"
  ntp_servers         = "${var.ntpServers}"

  tags = "${merge( local.default_tags, map (
    "Name", "dhcpopts-vpc-${var.deptName}-${var.appName}-${var.envName}-${var.region}",
    "Ci", ""
  ))}"
}

# Associate DHCP Options to VPC for private and mixed VPCs
resource "aws_vpc_dhcp_options_association" "dhcp_opts_assoc" {
  count           = "${var.vpcType != "public" && var.create_dhcp_opts ? 1 : 0}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_opts.id}"
  vpc_id          = "${aws_vpc.vpc.id}"
}

##################################
# PUBLIC Internet

# Create an Internet Gateway for the VPC so the web subnets can talk to internet
# if var.vpcType != private
resource "aws_internet_gateway" "igw" {
  count  = "${var.vpcType != "private" ? 1 : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  tags = "${merge( local.default_tags, map (
    "Name", "igw-${var.deptName}-${var.appName}-${var.envName}-${var.vpcType}-${var.region}",
    "Ci", ""
  ))}"
}

# Create a single public route table
# if var.vpcType == public
resource "aws_route_table" "public_routetable" {
  count  = "${var.vpcType != "private" ? 1 : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  tags = "${merge( local.default_tags, map (
    "Name", "rt-public-${var.deptName}-${var.appName}-${var.envName}-${var.region}",
    "Ci", ""
  ))}"
}

# Add a rule to the public route table, making the Internet GW the default route
# if var.vpcType != private and var.create_web_subnets == true
resource "aws_route" "igw_route" {
  count          = "${var.vpcType != "private" && var.create_web_subnets ? 1 : 0}"
  route_table_id = "${aws_route_table.public_routetable.id}"
  gateway_id     = "${aws_internet_gateway.igw.id}"

  destination_cidr_block = "0.0.0.0/0"
}

####################################
# Nat Gateway

# Create one elastic IP to be used by the NAT gateway
# if var.vpcType == public && var.create_natgw == true
resource "aws_eip" "ngw_eip" {
  count = "${var.vpcType == "public" && var.create_natgw ? 1 : 0}"
  vpc   = true
}

# Add Nat gateway to the first web_subnet
# if var.vpcType == public && var.create_natgw == true
# NOTE: this is not HA. but outbound internet access for private subents isnt business critical
resource "aws_nat_gateway" "ngw" {
  count         = "${var.vpcType == "public" && var.create_natgw ? 1 : 0}"
  allocation_id = "${aws_eip.ngw_eip.id}"
  subnet_id     = "${element(aws_subnet.web_subnet.*.id, 0)}"
  depends_on    = ["aws_internet_gateway.igw"]

  tags = "${merge( local.default_tags, map (
    "Name", "nat-${var.deptName}-${var.appName}-${var.envName}-public-${var.region}",
    "Ci", ""
  ))}"
}

# Add a rule to vpc default route table, making the Nat GW the default route
# if var.vpcType == public and var.create_default_vpc_route == true && var.create_natgw == true
resource "aws_route" "ngw_route" {
  count                  = "${var.vpcType == "public" && var.create_vpc_default_route && var.create_natgw ? 1 : 0}"
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  nat_gateway_id         = "${aws_nat_gateway.ngw.id}"
  destination_cidr_block = "0.0.0.0/0"
}

####################################
# Transit Gateway Attachment

# Create a Transit Gateway Attachment for the VPC to the app subnets (one subnet per az)
# if var.vpcType != public && var.create_app_subnets == false
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_app_attach" {
  count  = "${var.attach_to_tgw != false && var.vpcType != "public" && var.create_app_subnets ? 1 : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  subnet_ids = [
    "${aws_subnet.app_subnet.*.id}",
  ]

  transit_gateway_id = "${data.terraform_remote_state.aws_dotc-infra-prd_net-transitgw-prd.tgw_ids[var.region]}"

  tags = "${merge( local.default_tags, map (
    "Name", "tgwattch-${aws_vpc.vpc.id}-${var.region}",
    "Ci", ""
  ))}"
}

# Add a rule to vpc default route table, making the Transit GW the default route
# if var.vpcType != public && var.create_app_subnets == false
resource "aws_route" "tgw_route" {
  count                  = "${var.attach_to_tgw != false && var.vpcType != "public" && var.create_vpc_default_route ? 1 : 0}"
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  transit_gateway_id     = "${aws_ec2_transit_gateway_vpc_attachment.tgw_app_attach.transit_gateway_id}"
  destination_cidr_block = "0.0.0.0/0"
}

# Create a Transit Gateway Attachment for the VPC to the db subnets (one subnet per az)
# if var.vpcType != public && var.create_app_subnets == false && var.create_db_subnets == true
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_db_attach" {
  count  = "${var.attach_to_tgw != false && var.vpcType != "public" && ! var.create_app_subnets && var.create_db_subnets ? 1 : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  subnet_ids = [
    "${aws_subnet.database_subnet.*.id}",
  ]

  transit_gateway_id = "${data.terraform_remote_state.aws_dotc-infra-prd_net-transitgw-prd.tgw_ids[var.region]}"

  tags = "${merge( local.default_tags, map (
    "Name", "tgwattch-${aws_vpc.vpc.id}-${var.region}",
    "Ci", ""
  ))}"
}

# Create a Transit Gateway Attachment for the VPC to the web subnets (one subnet per az)
# if var.vpcType != public && var.create_app_subnets == false && var.create_db_subnets == false
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_web_attach" {
  count  = "${var.attach_to_tgw != false && var.vpcType != "public" && ! var.create_app_subnets && ! var.create_db_subnets ? 1 : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  subnet_ids = [
    "${aws_subnet.web_subnet.*.id}",
  ]

  transit_gateway_id = "${data.terraform_remote_state.aws_dotc-infra-prd_net-transitgw-prd.tgw_ids[var.region]}"

  tags = "${merge( local.default_tags, map (
    "Name", "tgwattch-${aws_vpc.vpc.id}-${var.region}",
    "Ci", ""
  ))}"
}

##########################################
# Web Subnets

# Create var.azQty public subnet(s)
# if var.create_web_subnets == true
resource "aws_subnet" "web_subnet" {
  count                   = "${var.create_web_subnets ? var.azQty : 0}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${cidrsubnet(var.vpcCidr, var.subnetBits, count.index)}"
  availability_zone       = "${var.region}${element(local.azSuffixes, count.index)}"
  map_public_ip_on_launch = true

  tags = "${merge( local.default_tags, map (
    "Name", "sn-web-${var.deptName}-${var.appName}-${var.envName}-${var.region}${element(local.azSuffixes, count.index)}",
    "Ci", ""
  ))}"
}

#  Associate all web Subnets to the public Route Table
# if var.vpcType != private and var.create_web_subnets == true
resource "aws_route_table_association" "publicRteTblAssoc" {
  count          = "${var.vpcType != "private" && var.create_web_subnets ? var.azQty : 0}"
  subnet_id      = "${element(aws_subnet.web_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_routetable.id}"
}

###############################################################
# App Subnets

# Create var.azQty private app subnet(s) if var.create_app_subnets == true
resource "aws_subnet" "app_subnet" {
  count                   = "${var.create_app_subnets ? var.azQty : 0}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${cidrsubnet(var.vpcCidr, var.subnetBits, count.index + length(aws_subnet.web_subnet.*.id))}"
  availability_zone       = "${var.region}${element(local.azSuffixes, count.index)}"
  map_public_ip_on_launch = false

  tags = "${merge( local.default_tags, map (
    "Name", "sn-app-${var.deptName}-${var.appName}-${var.envName}-${var.region}${element(local.azSuffixes, count.index)}",
    "Ci", ""
  ))}"
}

###############################################################
# Database Subnets

# Create var.azQty database private subnet if var.create_db_subnets == true
resource "aws_subnet" "database_subnet" {
  count                   = "${var.create_db_subnets ? var.azQty : 0}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${cidrsubnet(var.vpcCidr, var.subnetBits, count.index + length(aws_subnet.web_subnet.*.id) +  length(aws_subnet.app_subnet.*.id))}"
  availability_zone       = "${var.region}${element(local.azSuffixes, count.index)}"
  map_public_ip_on_launch = false

  tags = "${merge( local.default_tags, map (
    "Name", "sn-db-${var.deptName}-${var.appName}-${var.envName}-${var.region}${element(local.azSuffixes, count.index)}",
    "Ci", ""
  ))}"
}
