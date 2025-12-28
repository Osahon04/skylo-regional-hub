output "vpc_id" { value = module.vpc.vpc_id }
output "tgw_attachment_id" { value = module.tgw_attachment.attachment_id }
output "eks_cluster_name" { value = module.eks.cluster_name }
