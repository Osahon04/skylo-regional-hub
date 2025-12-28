resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-igw" }
}

# --- Subnets ---
resource "aws_subnet" "public" {
  for_each = toset(var.azs)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = var.public_subnet_cidrs[index(var.azs, each.value)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${each.value}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = var.private_app_subnet_cidrs[index(var.azs, each.value)]

  tags = {
    Name = "${var.name}-private-app-${each.value}"
    Tier = "private-app"
  }
}

resource "aws_subnet" "private_data" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = var.private_data_subnet_cidrs[index(var.azs, each.value)]

  tags = {
    Name = "${var.name}-private-data-${each.value}"
    Tier = "private-data"
  }
}

resource "aws_subnet" "tgw" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = var.tgw_subnet_cidrs[index(var.azs, each.value)]

  tags = {
    Name = "${var.name}-tgw-${each.value}"
    Tier = "tgw"
  }
}

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-rt-public" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT per AZ
resource "aws_eip" "nat" {
  for_each = toset(var.azs)
  domain   = "vpc"
  tags = { Name = "${var.name}-nat-eip-${each.value}" }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(var.azs)

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = { Name = "${var.name}-nat-${each.value}" }

  depends_on = [aws_internet_gateway.this]
}

# Private route table per AZ -> NAT in same AZ
resource "aws_route_table" "private_app" {
  for_each = toset(var.azs)
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-rt-private-app-${each.value}" }
}

resource "aws_route" "private_app_default" {
  for_each = toset(var.azs)

  route_table_id         = aws_route_table.private_app[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

# Data route tables (can be no-internet by default; or NAT if needed)
resource "aws_route_table" "private_data" {
  for_each = toset(var.azs)
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-rt-private-data-${each.value}" }
}

resource "aws_route_table_association" "private_data" {
  for_each = aws_subnet.private_data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_data[each.key].id
}

# TGW subnets route tables (typically just associations; TGW routes handled by TGW)
resource "aws_route_table" "tgw" {
  for_each = toset(var.azs)
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-rt-tgw-${each.value}" }
}

resource "aws_route_table_association" "tgw" {
  for_each = aws_subnet.tgw
  subnet_id      = each.value.id
  route_table_id = aws_route_table.tgw[each.key].id
}
