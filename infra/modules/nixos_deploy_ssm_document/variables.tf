variable "action" {
  description = "Whether to switch or reboot to deploy."
  type        = string
  default     = "switch"
}

variable "profile" {
  description = ""
  type        = string
  default     = "/nix/var/nix/profiles/system"
}

variable "installable" {
  description = "The configuration to deploy. Either a nix flake attribute or a nix store path. When a flake attribute is provided, the flake is evaluated on the machine. This might run out of memory on small instances. If a store path is provided, the path is substituted from a substituter."
  type        = string
  default     = ""
}

variable "substituters" {
  description = "The substituters to use."
  type        = string
  default     = ""
}

variable "trusted_public_keys" {
  description = "The key with which to verify the substituters."
  type        = string
  default     = ""
}
