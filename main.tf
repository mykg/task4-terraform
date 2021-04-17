# configure the provider
provider "aws" {
  region = "ap-south-1"
  profile = "terraform-user"
}

#Creating private key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "generated_key" {
    key_name = "task3_key"
    public_key = tls_private_key.key.public_key_openssh

    depends_on = [
        tls_private_key.key
    ]
}

#Downloading priavte key
resource "local_file" "file" {
    content  = tls_private_key.key.private_key_pem
    filename = "E:/Terraform/tasks cloud trainig/task3/task4_key.pem"
    file_permission = "0400"

    depends_on = [ aws_key_pair.generated_key ]
}

# creating a vpc
resource "aws_vpc" "vpc" {
  cidr_block       = "192.169.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc"
  }
}

# creating subnet in 1a
resource "aws_subnet" "sub_1a" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "192.169.1.0/24"
  availability_zone = "ap-south-1a" 
  map_public_ip_on_launch  =  true

  tags = {
    Name = "sub_1a"
  }
  depends_on = [ aws_vpc.vpc ]
}

# creating a subnet in 1b
resource "aws_subnet" "sub_1b" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "192.169.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "sub_1b"
  }
  depends_on = [ aws_vpc.vpc ]
}

# creating igw
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "igw"
  }
  depends_on = [ aws_vpc.vpc ]
}

# creating route table
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "r"
  }
  depends_on = [ aws_internet_gateway.igw, aws_vpc.vpc ]
}

# associating route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub_1a.id
  route_table_id = aws_route_table.r.id

  depends_on = [ aws_route_table.r ]
}

# Creating Elastic ip
resource "aws_eip" "public_ip" {
  vpc      = true
}

#creating Nat Gateway
resource "aws_nat_gateway" "NAT-gw" {
  allocation_id = aws_eip.public_ip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NAT-GW"
  }
}

#Creating routing table to access NAT Gateway
resource "aws_route_table" "r2" {
  vpc_id =  aws_vpc.vpc.id

route {
    cidr_block = "0.0.0.0/0"
     gateway_id = aws_nat_gateway.NAT-gw.id
}
   
 tags = {
    Name = "NAT_table"
  }
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.r2.id
}

# sg for wordpress
resource "aws_security_group" "wp_sg" {
  name        = "wp sg"
  description = "Allow http ssh all"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wp sg"
  }
}

# sg for mysql
resource "aws_security_group" "mysql_sg" {
  name        = "mysql sg"
  description = "ssh and mysql port"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "mysql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql sg"
  }
  depends_on = [ aws_vpc.vpc ]
}

# wordpress ami
resource "aws_instance" "wordpress" {
    depends_on = [   aws_subnet.sub_1a, aws_security_group.wp_sg, ]
    
    ami           = "ami-02b9afddbf1c3b2e5"
    instance_type = "t2.micro"
    key_name = "task3_key"
    vpc_security_group_ids = ["${aws_security_group.wp_sg.id}"]
    subnet_id = aws_subnet.sub_1a.id
    tags = {
        Name = "WordPress"
    }
}

# mysql ami
resource "aws_instance" "mysql" {
    depends_on = [    aws_subnet.sub_1b, aws_security_group.mysql_sg, ]
    ami           = "ami-0d8b282f6227e8ffb"
    instance_type = "t2.micro"
    key_name = "task3_key"
    vpc_security_group_ids = ["${aws_security_group.mysql_sg.id}"]
    subnet_id = aws_subnet.sub_1b.id
    tags = {
        Name = "Mysql"
    }
}