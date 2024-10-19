resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16" 
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"  # Public Subnet range
  availability_zone = "us-east-1a"   # Change to the preferred availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "my-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"  # Private Subnet range
  availability_zone = "us-east-1a"   # Change to the preferred availability zone
  map_public_ip_on_launch = false  # No public IP for resources in the private subnet

  tags = {
    Name = "my-private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "my-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id  # NAT Gateway in the public subnet

  tags = {
    Name = "my-nat-gateway"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id  # Public route via Internet Gateway
  }

  tags = {
    Name = "public-route-table"
  }
}


# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a route table for the private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my_vpc.id

  # Route all outbound traffic through the NAT Gateway for internet access
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id  # Private subnet's outbound traffic goes via NAT
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate the route table with the private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Output the VPC and Subnet IDs
output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

resource "aws_instance" "my_ec2" {
  ami           = data.aws_ami.latest-ubuntu-image.id
  instance_type = "t3.micro"
}

data "aws_ami" "latest-ubuntu-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-ubuntu-image.id
}

resource "aws_elb" "my_elb" {
  name               = "my-elb"
  subnets            = [aws_subnet.public.id]  

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "my-elb"
  }
}

resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "my-launch-template-"
  image_id      = data.aws_ami.latest-ubuntu-image.id
  instance_type = "t3.micro"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo docker pull yeasy/simple-web
              sudo docker run -d -p 80:80 yeasy/simple-web
            EOF
  )
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my_asg.id
  elb                    = aws_elb.my_elb.id  # Attach the ELB directly to the ASG
}

resource "aws_autoscaling_group" "my_asg" {
  launch_template {
    id      = aws_launch_template.my_launch_template.id
  }
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.private.id]

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }
}
