locals {
  cidrs = {
    private = {
      for i, v in var.availability_zones : v => {
        ipv4 = cidrsubnet(aws_vpc.this.cidr_block, 4, i)
        ipv6 = cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, i)
      }
    }
    public = {
      for i, v in var.availability_zones : v => {
        ipv4 = cidrsubnet(aws_vpc.this.cidr_block, 4, i + length(var.availability_zones))
        ipv6 = cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, i + length(var.availability_zones))
      }
    }
  }
}
