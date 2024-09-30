output "id" {
  value = aws_vpc.this.id
}

output "private_subnets" {
  value = values(aws_subnet.private)[*].id
}

output "public_subnets" {
  value = values(aws_subnet.public)[*].id
}

output "eic_endpoint_security_group_id" {
  value = aws_security_group.ec2_instance_connect_endpoint.id
}
