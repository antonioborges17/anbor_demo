variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "VPC the security group is created in"
  type        = string
}

variable "public_tcp_ports" {
  description = "TCP ports opened to allowed_cidr"
  type        = list(number)
  default     = [22, 30443]
}

variable "allowed_cidr" {
  description = "CIDR block allowed to reach the public ports"
  type        = string
  default     = "0.0.0.0/0"
}
