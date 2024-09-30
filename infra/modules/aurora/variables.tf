variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_identifier" {
  description = "The identifier"
  type        = string
  default     = null
}

variable "cluster_identifier_prefix" {
  description = "The prefix for the cluster identifier"
  type        = string
  default     = null
}

variable "availability_zones" {
  type = list(string)
}

variable "instance_count" {
  type        = number
  description = "The number of instances to create"
  default     = 2
}

variable "min_capacity" {
  type        = number
  description = "The minimum capacity of the Aurora Serverless v2 cluster"
  default     = 0.5
}

variable "max_capacity" {
  type        = number
  description = "The maximum capacity of the Aurora Serverless v2 cluster"
  default     = 1
}
