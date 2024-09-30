resource "aws_vpc" "this" {
  cidr_block                       = var.cidr_block
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true
  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-rtb-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-rtb-public"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}


resource "aws_subnet" "private" {
  for_each          = local.cidrs.private
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.ipv4
  ipv6_cidr_block   = each.value.ipv6
  availability_zone = each.key
  # NOTE: NixOS doesnt work with ipv6
  assign_ipv6_address_on_creation                = false
  private_dns_hostname_type_on_launch            = "resource-name"
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  tags = {
    Name = "${var.name}-subnet-private-${each.key}"
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
  for_each                                       = local.cidrs.public
  vpc_id                                         = aws_vpc.this.id
  cidr_block                                     = each.value.ipv4
  ipv6_cidr_block                                = each.value.ipv6
  availability_zone                              = each.key
  assign_ipv6_address_on_creation                = false
  private_dns_hostname_type_on_launch            = "resource-name"
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  tags = {
    Name = "${var.name}-subnet-public-${each.key}"
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
    "Name" = "${var.name}-rtb-default"
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

data "aws_region" "this" {}


# Connectivity to AWS services

# Give private subnets access to S3 and DynamoDB via a VPC Gateway Endpoint
resource "aws_vpc_endpoint" "gateway" {
  for_each     = toset(["s3", "dynamodb"])
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.this.name}.${each.key}"
  tags = {
    Name = "${var.name}-vpce-${each.key}"
  }
}

resource "aws_vpc_endpoint_route_table_association" "gateway" {
  for_each        = aws_vpc_endpoint.gateway
  vpc_endpoint_id = each.value.id
  route_table_id  = aws_route_table.private.id
}

resource "aws_security_group" "ec2_instance_connect_endpoint" {
  name   = "${var.name}-eice"
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-eice"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_instance_connect_endpoint" {
  security_group_id = aws_security_group.ec2_instance_connect_endpoint.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_instance_connect_endpoint_v6" {
  security_group_id = aws_security_group.ec2_instance_connect_endpoint.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"
}

resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = aws_subnet.private["eu-central-1a"].id
  security_group_ids = [aws_security_group.ec2_instance_connect_endpoint.id]
}


resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-eigw"
  }
}

resource "aws_route" "egress_ipv6" {
  route_table_id              = aws_route_table.private.id
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this.id
  destination_ipv6_cidr_block = "::/0"
}

resource "aws_eip" "nat_gateway" {
  tags = {
    Name = "${var.name}-eip"
  }
}

resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public["eu-central-1a"].id
  allocation_id = aws_eip.nat_gateway.id
  tags = {
    Name = "${var.name}-ngw"
  }
}

resource "aws_route" "egress_ipv4" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}

/*resource "aws_vpc_endpoint" "ssm" {
  for_each          = toset(["ssm", "ssmmessages", "ec2messages"])
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.name}.${each.key}"
  vpc_endpoint_type = "Interface"
  subnet_ids        = values(aws_subnet.private)[*].id
  tags = {
    Name = "${var.name}-vpce-${each.key}"
  }
}

resource "aws_vpc_endpoint_route_table_association" "ssm" {
  for_each        = aws_vpc_endpoint.ssm
  vpc_endpoint_id = each.value.id
  route_table_id  = aws_route_table.private.id
}*/
