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

