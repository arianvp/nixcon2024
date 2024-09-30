output "private_subnets_ids" {
  value = { for az, subnet in aws_subnet.private : az => subnet.id }
}
