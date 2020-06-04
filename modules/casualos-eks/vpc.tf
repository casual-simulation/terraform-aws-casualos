# Creates the VPC and all the Subnets and routes needed for the cluster.

locals {
  vpc_name = "${local.cluster_name}-vpc"
  azs      = ["us-east-1a", "us-east-1b"]

  # The tags that should be applied to the VPC.
  # EKS has special requirements so that their Kubernetes implementation knows
  # where to put things.
  # See https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#vpc-subnet-tagging
  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  # These tags tell EKS that the public subnets should be used for internet-facing load balancers.
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  # These tags tell EKS that the private subnets should be used for internal-facing load balancers.
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  tags = merge({
    Name = local.vpc_name
  }, local.tags)

  enable_dns_hostnames = true
}

# Create our public subnets
# These will house the load balancers.
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = true

  tags = merge({
    Name = "${local.vpc_name}-public1"
  }, local.tags, local.public_subnet_tags)
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = true

  tags = merge({
    Name = "${local.vpc_name}-public2"
  }, local.tags, local.public_subnet_tags)
}

# Create our private subnets
# These will house the EC2 instances
resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = false

  tags = merge({
    Name = "${local.vpc_name}-private1"
  }, local.tags, local.private_subnet_tags)
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = false

  tags = merge({
    Name = "${local.vpc_name}-private2"
  }, local.tags, local.private_subnet_tags)
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = merge({
    Name = "${local.vpc_name}-public"
  }, local.tags)
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name = "${local.vpc_name}-private"
    },
    local.tags,
  )

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = [propagating_vgws]
  }
}

# Attach our route tables to the subnets
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# Create an internet gateway to give our public subnet access from the internet.
resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      "Name" = local.vpc_name
    },
    local.tags,
  )
}

# Create an elastic IP that the NAT gateway can use to access the internet.
resource "aws_eip" "nat" {
  vpc = true
  tags = merge(
    {
      Name = "${local.vpc_name}-nat"
    },
    local.tags,
  )
}

# Create a NAT gateway that allows the subnet to access the internet but not the other way around.
resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.nat.id

  # This is the subnet that the NAT gateway instance is placed in.
  subnet_id = aws_subnet.public1.id

  tags = merge(
    {
      Name = "${local.vpc_name}-public"
    },
    local.tags,
  )

  depends_on = [aws_internet_gateway.public]
}

# Create routes for our route tables
# These routes give our public subnets access from the internet
# and our private subnets access to the internet (but not the other way around)
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public.id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private.id

  timeouts {
    create = "5m"
  }
}