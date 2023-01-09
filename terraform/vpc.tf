# Networking for Fargate
# Note: 10.0.0.0 and 10.0.2.0 are private IPs
# Required via https://stackoverflow.com/a/66802973/1002357
# """
# > Launch tasks in a private subnet that has a VPC routing table configured to route outbound 
# > traffic via a NAT gateway in a public subnet. This way the NAT gateway can open a connection 
# > to ECR on behalf of the task.
# """
# If this networking configuration isn't here, this error happens in the ECS Task's "Stopped reason":
# ResourceInitializationError: unable to pull secrets or registry auth: pull command failed: : signal: killed

resource "aws_vpc" "clamav_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mm-prod-clamav-vpc"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.clamav_vpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "mm-prod-clamav-vpc-private-subnet-1"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.clamav_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "mm-prod-clamav-vpc-public-subnet-1"
  }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.clamav_vpc.default_route_table_id

  route = []

  tags = {
    Name = "mm-prod-clamav-vpc-rtb-default"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.clamav_vpc.id
  tags = {
    Name = "mm-prod-clamav-vpc-rtb-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.clamav_vpc.id
  tags = {
    Name = "mm-prod-clamav-vpc-rtb-public"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.clamav_vpc.id
  tags = {
    Name = "mm-prod-clamav-vpc-igw"
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "mm-prod-clamav-nat-ip"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id

  tags = {
    Name = "mm-prod-clamav-vpc-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

# resource "aws_vpc_endpoint" "s3-endpoint" {
#   vpc_id            = aws_vpc.clamav_vpc.id
#   service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [aws_route_table.private.id]
# }

# resource "aws_vpc_endpoint" "sqs-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.sqs"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "logs-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "ecr-dkr-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "ecr-api-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "ecs-agent-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecs-agent"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "ecs-telemetry-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecs-telemetry"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_vpc_endpoint" "ecs-endpoint" {
#   vpc_id              = aws_vpc.clamav_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecs"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   security_group_ids  = [aws_security_group.ingress-all.id]
#   subnet_ids          = [aws_subnet.private.id]
# }

# resource "aws_security_group" "ingress-all" {
#   name        = "ingress_all"
#   description = "Allow 80 & 443 inbound traffic"
#   vpc_id      = aws_vpc.clamav_vpc.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

resource "aws_security_group" "egress-all" {
  name        = "egress_all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.clamav_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
