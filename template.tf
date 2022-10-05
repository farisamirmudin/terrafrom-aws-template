terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.33.0"
    }
  }
}

provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
#   profile                  = "default"
  region                   = "ap-southeast-1"
}

# 1. create vpc
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.3.0.0/16"

  tags = {
    Name = "prod-vpc"
  }
}
# 2. create internet gateway
resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod_gw"
  }
}
# 3. create custom route table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  tags = {
    Name = "prod_route_table"
  }
}
# 4. create subnet
resource "aws_subnet" "prod_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.3.10.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "prod_subnet"
  }
}
# 5. associate subnet to route table
resource "aws_route_table_association" "prod_rta" {
  subnet_id      = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}
# 6. create security group to allow port 22, 80, 443
resource "aws_security_group" "prod_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "prod_sg"
  }
}
# 7. create a network interface
resource "aws_network_interface" "prod_interface" {
  subnet_id   = aws_subnet.prod_subnet.id
  private_ips = ["10.3.10.100"]
  security_groups = [aws_security_group.prod_sg.id]

  tags = {
    Name = "prod_interface"
  }
}
# 8. assign an elastic ip to the network interface
resource "aws_eip" "prod_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.prod_interface.id
  associate_with_private_ip = "10.3.10.100"
  depends_on = [aws_internet_gateway.prod_gw]
}

# 9. create ubuntu and install apache
resource "aws_instance" "prod_instance" {
  ami           = "ami-07651f0c4c315a529"
  instance_type = "t2.micro"
  availability_zone = "ap-southeast-1a"

  network_interface {
    network_interface_id = aws_network_interface.prod_interface.id
    device_index         = 0
  }
  tags = {
    "Name" = "prod_instance"
  }
  user_data = <<-EOF
            #!/bin/bash
            sudo apt update
            sudo apt install apache2 -y
            sudo systemctl enable apache2
            sudo systemctl start apache2
            sudo bash -c 'echo "created using terraform" > /var/www/html/index.html'
            EOF
}
# output the public ip
output "instance_public_id" {
    value = aws_eip.prod_eip.public_ip
}

output "instance_id" {
    value = aws_instance.prod_instance.id
}