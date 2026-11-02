resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = {
    Name = var.name
  }
}

# One rule per port opened to the internet (or to var.allowed_cidr)
resource "aws_vpc_security_group_ingress_rule" "public_tcp" {
  for_each = toset([for p in var.public_tcp_ports : tostring(p)])

  security_group_id = aws_security_group.this.id
  description       = "TCP ${each.value} from ${var.allowed_cidr}"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = var.allowed_cidr
}

# All traffic between members of this security group
resource "aws_vpc_security_group_ingress_rule" "self_all" {
  security_group_id            = aws_security_group.this.id
  description                  = "All traffic from members of this security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this.id
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
