
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

resource "aws_instance" "k8s" {
  for_each = toset(var.instance_names)

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
  # (swap off, kernel modules, sysctls, containerd with systemd cgroups, kubelet/kubeadm/kubectl)
  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    package_reboot_if_required: true

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

    runcmd:
      - swapoff -a
      - sed -i '/ swap / s/^/#/' /etc/fstab
      - modprobe overlay
      - modprobe br_netfilter
      - sysctl --system
      - DEBIAN_FRONTEND=noninteractive apt-get install -y containerd apt-transport-https ca-certificates curl gpg
      - mkdir -p /etc/containerd
      - containerd config default > /etc/containerd/config.toml
      - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
      - systemctl restart containerd
      - systemctl enable containerd
      - mkdir -p -m 755 /etc/apt/keyrings
      - curl -fsSL https://pkgs.k8s.io/core:/stable:/${var.k8s_minor_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${var.k8s_minor_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
      - apt-get update
      - DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
      - apt-mark hold kubelet kubeadm kubectl
      - systemctl enable --now kubelet
  EOF

  tags = {
    Name = each.value
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
