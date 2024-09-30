variable "name" {
  type = string
}

variable "instance_type" {
  type        = string
  description = "The instance type to use"
}

variable "architecture" {
  type        = string
  description = "The architecture to use"
}

variable "vpc_id" {
  type = string
}

variable "security_group_ids" {
  type = set(string)
}

variable "key_name" {
  type    = string
  default = null
}

variable "public_subnets" {
  type = set(string)
}

variable "private_subnets" {
  type = set(string)
}

variable "nix_cache" {
  type = object({
    store_uri          = string
    trusted_public_key = string
    read_policy_arn    = string
  })
}
