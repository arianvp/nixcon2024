output "id" {
  value = aws_vpc.this.id
}

output "private_subnets" {
  value = aws_subnet.private
}

output "public_subnets" {
  value = aws_subnet.public
}

output "eic_endpoint_security_group_id" {
  value = aws_security_group.ec2_instance_connect_endpoint.id
}
