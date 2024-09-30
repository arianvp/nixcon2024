variable "availability_zones" {
  type = list(string)
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "name" {
  type = string
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.name
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}

locals {
  cidrs = {
    private = { for i, v in var.availability_zones : v => cidrsubnet(aws_vpc.this.cidr_block, 4, i) }
    public  = { for i, v in var.availability_zones : v => cidrsubnet(aws_vpc.this.cidr_block, 4, i + length(var.availability_zones)) }
  }
}

resource "aws_subnet" "private" {
  for_each          = local.cidrs.private
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_network_acl_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  network_acl_id = aws_default_network_acl.default.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_subnet" "public" {
  for_each          = local.cidrs.public
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}


resource "aws_network_acl_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  network_acl_id = aws_default_network_acl.default.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  tags = {
    "Name" = "${var.name}-default"
  }
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id
  subnet_ids             = setunion(values(aws_subnet.private)[*].id, values(aws_subnet.public)[*].id)

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.name}-default"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
}

output "id" {
  value = aws_vpc.this.id
}
