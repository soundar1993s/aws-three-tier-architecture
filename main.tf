terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "multi_az_database" {
  type    = bool
  default = true
}

variable "enable_schema_bootstrap" {
  description = "Temporarily permit the app instance role to read the RDS master secret during schema setup."
  type        = bool
  default     = false
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "guvi-project01" }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

locals {
  project  = "guvi-project01"
  vpc_cidr = "10.0.0.0/16"
  tiers = {
    web = 0
    app = 2
    db  = 4
  }
  subnets = merge([
    for tier, offset in local.tiers : {
      for index in range(2) : "${tier}-${index + 1}" => {
        tier = tier
        az   = data.aws_availability_zones.available.names[index]
        cidr = cidrsubnet(local.vpc_cidr, 7, offset + index)
      }
    }
  ]...)
}

resource "aws_vpc" "project" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.project }
}

resource "aws_subnet" "tier" {
  for_each          = local.subnets
  vpc_id            = aws_vpc.project.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  tags              = { Name = "${local.project}-${each.key}" }
}

resource "aws_internet_gateway" "project" {
  vpc_id = aws_vpc.project.id
  tags   = { Name = local.project }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.project}-nat" }
}

resource "aws_nat_gateway" "app" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.tier["web-1"].id
  depends_on    = [aws_internet_gateway.project]
  tags          = { Name = "${local.project}-nat" }
}

resource "aws_route_table" "tier" {
  for_each = local.tiers
  vpc_id   = aws_vpc.project.id
  tags     = { Name = "${local.project}-${each.key}" }
}

resource "aws_route" "web" {
  route_table_id         = aws_route_table.tier["web"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project.id
}

resource "aws_route" "app" {
  route_table_id         = aws_route_table.tier["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.app.id
}

resource "aws_route_table_association" "tier" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.tier[each.key].id
  route_table_id = aws_route_table.tier[each.value.tier].id
}

locals {
  tier_connections = {
    public_to_web = { from = "public-alb", to = "web", port = 80 }
    web_to_lb     = { from = "web", to = "internal-alb", port = 80 }
    lb_to_app     = { from = "internal-alb", to = "app", port = 5000 }
    app_to_db     = { from = "app", to = "db", port = 3306 }
  }
  ec2_egress = {
    web_http  = { tier = "web", port = 80 }
    web_https = { tier = "web", port = 443 }
    app_http  = { tier = "app", port = 80 }
    app_https = { tier = "app", port = 443 }
  }
}

resource "aws_security_group" "tier" {
  for_each    = toset(["public-alb", "web", "internal-alb", "app", "db"])
  name        = "${local.project}-${each.key}"
  description = "Traffic rules for the ${each.key} tier"
  vpc_id      = aws_vpc.project.id
  tags        = { Name = "${local.project}-${each.key}" }
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.tier["public-alb"].id
  description       = "Public lab HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "tier" {
  for_each                     = local.tier_connections
  security_group_id            = aws_security_group.tier[each.value.to].id
  referenced_security_group_id = aws_security_group.tier[each.value.from].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "tier" {
  for_each                     = local.tier_connections
  security_group_id            = aws_security_group.tier[each.value.from].id
  referenced_security_group_id = aws_security_group.tier[each.value.to].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "bootstrap" {
  for_each          = local.ec2_egress
  security_group_id = aws_security_group.tier[each.value.tier].id
  description       = "Package repositories and AWS service endpoints"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}
