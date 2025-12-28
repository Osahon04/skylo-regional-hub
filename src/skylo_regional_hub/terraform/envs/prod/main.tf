module "vpc" {
  source = "../../../modules/vpc"

  name               = var.name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs

  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  tgw_subnet_cidrs         = var.tgw_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "tgw_attachment" {
  source = "../../../modules/tgw-attachment"

  name              = var.name
  transit_gateway_id = var.transit_gateway_id  # mock / existing
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.tgw_subnet_ids

  # you can optionally add TGW route table association/propagation later
}

module "eks" {
  source = "../../../modules/eks-skeleton"

  name       = var.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_app_subnet_ids

  # intentionally minimal "skeleton"
  cluster_version = "1.29"
}
