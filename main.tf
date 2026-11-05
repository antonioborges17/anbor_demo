
provider "aws" {
  region = var.region
}

############################
# Network lookups (default VPC)
############################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################
# AMI (latest Ubuntu 24.04 LTS from Canonical)
############################

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

############################
# Security group
############################

module "security" {
  source = "./modules/security"

  name             = "k8s-cluster-sg"
  description      = "Kubernetes nodes: SSH and 30443 from the internet, all traffic within the group"
  vpc_id           = data.aws_vpc.default.id
  public_tcp_ports = [22, 30443]
}

############################
# EC2 instances
############################

# Linux user on the control plane for the web portal: SSH key login only
# (no password, no sudo). Its kubeconfig is installed by scripts/config_rbac_usercert.sh.
locals {
  web_admin_user = {
    name                = "web-admin"
    gecos               = "Web portal admin"
    shell               = "/bin/bash"
    lock_passwd         = true
    ssh_authorized_keys = [trimspace(file(pathexpand(var.web_admin_public_key_path)))]
  }

  # Control plane only. Installs tsh and tctl (the package also includes the unused teleport server).
  teleport_install_cmd = "curl -fsSL https://cdn.teleport.dev/install.sh | bash -s 18.11.8 oss"
}

resource "aws_instance" "k8s" {
  for_each = var.instances

  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [module.security.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # cloud-init (first boot only): upgrade packages, then prepare the node for kubeadm
  # (swap off, kernel modules, sysctls, containerd with systemd cgroups, kubelet/kubeadm/kubectl, helm, repo scripts in /home/ubuntu/scripts).
  # The control plane also gets the Teleport tools (tsh, tctl).
  user_data = <<-EOF
    #cloud-config
    hostname: ${each.value}
    manage_etc_hosts: true
    package_update: true
    package_upgrade: true
    package_reboot_if_required: true
    # "default" keeps the ubuntu user and the EC2 key pair; the control plane also gets web-admin
    users: ${each.key == "k8s-ctrl" ? jsonencode(["default", local.web_admin_user]) : jsonencode(["default"])}
    packages:
      - containerd

    write_files:
      - path: /etc/modules-load.d/k8s.conf
        content: |
          overlay
          br_netfilter
      - path: /etc/sysctl.d/k8s.conf
        content: |
          net.bridge.bridge-nf-call-ip6tables=1
          net.bridge.bridge-nf-call-iptables=1
          net.ipv4.ip_forward=1
      # deferred: written after the package upgrade, so apt doesn't see the repo before its key exists
      - path: /etc/apt/sources.list.d/kubernetes.list
        defer: true
        content: |
          deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${var.k8s_minor_version}/deb/ /

    runcmd:
      - swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab
      - modprobe -a overlay br_netfilter && sysctl --system
      - mkdir -p /etc/containerd && containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml && systemctl restart containerd
      - curl -fsSL https://pkgs.k8s.io/core:/stable:/${var.k8s_minor_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      - apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl
      - curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && helm version
      - git clone --depth 1 --filter=blob:none --sparse ${var.scripts_repo_url} /tmp/repo && git -C /tmp/repo sparse-checkout set --no-cone /scripts/ && cp -r /tmp/repo/scripts /home/ubuntu/scripts && rm -rf /tmp/repo && chown -R ubuntu:ubuntu /home/ubuntu/scripts${each.key == "k8s-ctrl" ? "\n  - ${local.teleport_install_cmd}" : ""}
  EOF

  tags = {
    Name = each.key
  }
}

############################
# Outputs
############################

output "instances" {
  description = "Public and private IPs per instance"
  value = {
    for name, inst in aws_instance.k8s : name => {
      public_ip  = inst.public_ip
      private_ip = inst.private_ip
    }
  }
}
