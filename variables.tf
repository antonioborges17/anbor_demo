############################
# Variables
############################

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH access"
  type        = string
  default     = "k8s-lab"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.small"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "instances" {
  description = "Instances to create: Name tag => hostname set on the node at first boot"
  type        = map(string)
  default = {
    "k8s-ctrl"    = "control-plane"
    "k8s-worker1" = "worker1"
    "k8s-worker2" = "worker2"
  }
}

variable "k8s_minor_version" {
  description = "Kubernetes minor version for the pkgs.k8s.io apt repo (e.g. v1.35)"
  type        = string
  default     = "v1.35"
}

variable "scripts_repo_url" {
  description = "Public Git repo whose scripts/ folder is downloaded to /home/ubuntu/scripts on each node"
  type        = string
  default     = "https://github.com/antonioborges17/anbor_demo"
}
