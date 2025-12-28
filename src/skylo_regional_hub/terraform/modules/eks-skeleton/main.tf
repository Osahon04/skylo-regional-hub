resource "aws_eks_cluster" "this" {
  name     = "${var.name}-eks"
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  tags = {
    Name = "${var.name}-eks"
  }
}

# NOTE: Nodegroups intentionally omitted (out of scope).
