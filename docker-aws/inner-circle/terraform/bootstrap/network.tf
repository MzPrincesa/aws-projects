resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "default-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "default-igw"
  }
}

# --- Subnets ---

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.0.0/20"
  availability_zone         = "us-east-1a"
  map_public_ip_on_launch  = true

  tags = {
    Name = "default-subnet-public1-us-east-1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.16.0/20"
  availability_zone         = "us-east-1b"
  map_public_ip_on_launch  = true

  tags = {
    Name = "default-subnet-public2-us-east-1b"
  }
}

resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.128.0/20"
  availability_zone         = "us-east-1a"
  map_public_ip_on_launch  = false

  tags = {
    Name = "default-subnet-private1-us-east-1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.144.0/20"
  availability_zone         = "us-east-1b"
  map_public_ip_on_launch  = false

  tags = {
    Name = "default-subnet-private2-us-east-1b"
  }
}

# --- Route tables ---

resource "aws_default_route_table" "main" {
  default_route_table_id = "rtb-06fbef01d49c11f3a"
  # Only the implicit local route — nothing else to declare
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "default-rtb-public"
  }
}

resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "default-rtb-private1-us-east-1a"
  }
}

resource "aws_route_table" "private_1b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "default-rtb-private2-us-east-1b"
  }
}

# --- Route table associations ---

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_1b.id
}

# --- Security groups ---

resource "aws_security_group" "alb_sg" {
  name        = "inner-circle-alb-sg"
  description = "Security group for Inner Circle ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "fargate_sg" {
  name        = "inner-circle-fargate-sg"
  description = "Security group for Inner Circle Fargate task"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "inner-circle-vpc-endpoints-sg"
  description = "Security group for Inner Circle VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}