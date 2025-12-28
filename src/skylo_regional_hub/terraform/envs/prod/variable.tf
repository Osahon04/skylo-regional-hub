variable "region" { type = string }
variable "name" { type = string }

variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }

variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_data_subnet_cidrs" { type = list(string) }
variable "tgw_subnet_cidrs" { type = list(string) }

variable "transit_gateway_id" {
  type        = string
  description = "Existing/TGW ID"
}
