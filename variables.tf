# variables.tf
variable "region" {
  description = "AWS region in which we will deploy resources"
  default     = "us-east-1"
}

variable "vpcType" {
  description = "Type of VPC to create [ public | private | mixed ]. Default is private."
  default     = "private"
}

variable "dnsServers" {
  description = "List of DNS server IP addresses to be provided via dhcpopts in private & mixed vpcs"
  type        = "list"

  default = [
    "10.250.2.10",
    "10.250.3.10",
    "10.1.97.12",
    "10.1.97.13",
  ]
}

variable "ntpServers" {
  description = "List of NTP servers to be provided via dhcp in private & mixed vpcs"
  type        = "list"

  default = [
    "10.1.97.240",
  ]
}

variable "dnsSuffix" {
  description = "DNS suffix provided to be via dhcp in private and mixed vpcs"
  default     = "dotcomm.org"
}

variable "azQty" {
  description = "Number of AZ to use for this VPC (one subnet per tier/az)"
  default     = "2"
}

variable "subnetBits" {
  description = "Subnet size in bits added to vpcCidr size. If vpcCidr is /21, 21+3 = /24 subnets. default = 3"
  default     = "3"
}

variable "create_vpc_default_route" {
  description = "Boolean. Create default route on default vpc route table? Set to false if providing custom default route"
  default     = true
}

variable "create_dhcp_opts" {
  description = "For non public subnets, should we create dotc specific dhcp options? Default = true"
  default     = true
}

variable "create_web_subnets" {
  description = "Boolean - should this module create the web subnets"
  default     = true
}

variable "create_app_subnets" {
  description = "Boolean - should this module create the app subnets"
  default     = true
}

variable "create_db_subnets" {
  description = "Boolean - should this module create the db subnets"
  default     = true
}

variable "create_natgw" {
  description = "Boolean - vpcType = 'public' gets a natgw unless set to false. default = true"
  default     = true
}

variable "attach_to_tgw" {
  description = "Boolean - vpcType != 'public' a transit gateway connection unless set to false. default = true"
  default     = true
}

variable "deptName" {
  description = "Name of the department that owns this VPC"
}

variable "appName" {
  description = "Name of the application that will use this VPC"
}

variable "envName" {
  description = "Name of the landscape (dev, qa, prod) for this VPC"
}

variable "vpcCidr" {
  description = "Cidr for the Virtual Private Cloud. i.e. '172.18.128.0/23'"
}

variable "create_ssm_endpoints" {
  description = "If true, creates 4 interface endpoints for ssm. ($.01/hr/ep) default = false"
  default     = false
}

variable "create_s3_endpoint" {
  description = "If true, creates the s3 gateway endpoint and adds to main vpc route table. default = true"
  default     = true
}

locals {
  azSuffixes = ["a", "b", "c", "d", "e"]

  # tags that we'll add to every resource in this workspace
  default_tags = "${map(
    "Department", "${var.deptName}",
    "Application", "${var.appName}",
    "Environment", "${var.envName}"
    )}"

  # A list of interface endpoint types to create
  endpoints = [
    "ec2",
    "ec2messages",
    "ssm",
    "ssmmessages",
  ]
}
