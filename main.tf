resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "my_route_table_assoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_security_group" "allow_ssh_http" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  availability_zones = ["us-east-1a"]
  security_groups    = [aws_security_group.allow_ssh_http.id] 

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

  instances = [aws_instance.my_ec2.id]
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

resource "aws_autoscaling_group" "my_asg" {
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$${aws_launch_template.my_launch_template.latest_version}"
  }
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.my_subnet.id]

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }
}
