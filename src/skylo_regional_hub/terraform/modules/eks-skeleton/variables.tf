variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN for EKS cluster "
  default     = "arn:aws:iam::123456789012:role/mock-eks-cluster-role"
}
