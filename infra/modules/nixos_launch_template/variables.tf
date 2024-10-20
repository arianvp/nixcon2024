variable "name" {
  type = string
}

variable "trusted_public_keys" {
  type        = string
  description = "The public keys to use for substitution"
}

variable "nix_cache" {
  type = object({
    store_uri          = string
    trusted_public_key = string
    read_policy_arn    = string
  })
}

variable "substituters" {
  type        = string
  description = "The substituters to trust"
}

variable "installable" {
  type        = string
  description = "The installable to use. Nix store path or flake ref"
  default     = null
}

variable "instance_type" {
  type        = string
  description = "The instance type to use"
}

variable "nixos_version" {
  type        = string
  description = "The NixOS version to use"
  default     = "24.05"
}

variable "architecture" {
  type        = string
  description = "The architecture to use"
}

variable "key_name" {
  type    = string
  default = null
}

variable "vpc_id" {
  type = string
}

variable "security_group_ids" {
  type = set(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
