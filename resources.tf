##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


data "template_file" "public_cidrsubnet" {
  count = local.total_subnet_count

  template = "$${cidrsubnet(vpc_cidr,8,current_count)}"

  vars = {
    vpc_cidr      = var.network_address_space[terraform.workspace]
    current_count = count.index
  }
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = var.network_address_space[terraform.workspace]
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.env_name}-webapp-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, { Name = "${local.env_name}-webapp-igw" })

}

resource "aws_subnet" "web_subnet" {
  count                   = var.web_subnet_count[terraform.workspace]
  cidr_block              = cidrsubnet("172.31.1.0/22", 2, count.index + 1)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = merge(local.common_tags, { Name = "${local.env_name}-web-${data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]}-subnet${count.index + 1}" })

}

resource "aws_subnet" "app_subnet" {
  count                   = var.app_subnet_count[terraform.workspace]
  cidr_block              = cidrsubnet("172.31.101.0/22", 2, count.index + 1)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = merge(local.common_tags, { Name = "${local.env_name}-app-${data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]}-subnet${count.index + 1}" })

}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, { Name = "${local.env_name}webapp-rt" })
}

resource "aws_route_table_association" "rta-web-subnet" {
  count          = var.web_subnet_count[terraform.workspace]
  subnet_id      = aws_subnet.web_subnet[count.index].id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-app-subnet" {
  count          = var.app_subnet_count[terraform.workspace]
  subnet_id      = aws_subnet.app_subnet[count.index].id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUPS #
resource "aws_security_group" "web_sg" {
  name   = "web_sg"
  vpc_id = aws_vpc.vpc.id

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["37.223.7.9/32"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.env_name}-elb-sg" })
}

# app security group 
resource "aws_security_group" "app_sg" {
  name   = "app_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from app
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["172.31.1.0/24"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["172.31.2.0/24"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["37.223.7.9/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.env_name}-app-sg" })
}

# db security group 
resource "aws_security_group" "db_sg" {
  name   = "db_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from app
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["172.31.101.0/24"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["172.31.102.0/24"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["37.223.7.9/32"]
  }
  
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.env_name}-app-sg" })
}

# INSTANCES #
resource "aws_instance" "web" {
  count                  = var.web_instance_count[terraform.workspace]
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = var.instance_size[terraform.workspace]
  subnet_id              = aws_subnet.web_subnet[count.index % var.web_subnet_count[terraform.workspace]].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }




  tags = merge(local.common_tags, { Name = "${local.env_name}-web${count.index + 1}" })
}

resource "aws_instance" "app" {
  count                  = var.app_instance_count[terraform.workspace]
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = var.instance_size[terraform.workspace]
  subnet_id              = aws_subnet.app_subnet[count.index % var.app_subnet_count[terraform.workspace]].id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }




  tags = merge(local.common_tags, { Name = "${local.env_name}-app${count.index + 1}" })
}

resource "aws_instance" "db" {
  count                  = 1
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = var.instance_size[terraform.workspace]
  subnet_id              = aws_subnet.app_subnet[count.index % var.app_subnet_count[terraform.workspace]].id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }




  tags = merge(local.common_tags, { Name = "${local.env_name}-db${count.index + 1}" })
}