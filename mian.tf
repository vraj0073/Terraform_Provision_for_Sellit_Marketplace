resource "aws_vpc" "exercise-2-vpc" {

    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
  
   tags = {
    Name = "exercise-2-vpc"
  }
}

resource "aws_internet_gateway" "exercise-2-internetgateway" {
    vpc_id = aws_vpc.exercise-2-vpc.id

  tags = {
    Name = "exercise2-internetway"
  }
  
}

resource "aws_subnet" "subnet_1_public" {
    vpc_id            = aws_vpc.exercise-2-vpc.id
  cidr_block        = "10.0.1.0/28"
  availability_zone = var.availability_zone[0]

  tags = {
    Name = "subnet-1-public"
  }

  
}

resource "aws_subnet" "subnet_2_public" {
  vpc_id            = aws_vpc.exercise-2-vpc.id
  cidr_block        = "10.0.2.0/28"
  availability_zone = var.availability_zone[1]

  tags = {
    Name = "subnet-2-public"
  }
}

resource "aws_subnet" "subnet_1_private" {
 vpc_id            = aws_vpc.exercise-2-vpc.id
  cidr_block        = "10.0.3.0/28"
  availability_zone = var.availability_zone[0]

  tags = {
    Name = "subnet-3-private"
  } 
}

resource "aws_subnet" "subnet_2_private" {
  vpc_id            = aws_vpc.exercise-2-vpc.id
  cidr_block        = "10.0.4.0/28"
  availability_zone = var.availability_zone[1]

  tags = {
    Name = "subnet-4-private"
  }
}

resource "aws_route_table" "exercise2-route-1-public" {
    vpc_id = aws_vpc.exercise-2-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.exercise-2-internetgateway.id
  }

  
  tags = {
    Name = "exercose-2-route-public"
  }
  
}

resource "aws_route_table" "exercise2-route-2-private" {
  vpc_id = aws_vpc.exercise-2-vpc.id
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "exercise2-private"
  }
}

resource "aws_route_table_association" "table-1-association" {

  subnet_id      = aws_subnet.subnet_1_public.id
  route_table_id = aws_route_table.exercise2-route-1-public.id
  
}

resource "aws_route_table_association" "table-2-association" {

  subnet_id      = aws_subnet.subnet_2_public.id
  route_table_id = aws_route_table.exercise2-route-1-public.id
  
}

resource "aws_route_table_association" "table-3-association" {

  subnet_id      = aws_subnet.subnet_1_private.id
  route_table_id = aws_route_table.exercise2-route-2-private.id
  
}

resource "aws_route_table_association" "table-4-association" {

  subnet_id      = aws_subnet.subnet_2_private.id
  route_table_id = aws_route_table.exercise2-route-2-private.id
  
}
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_1_public.id

  tags = {
    Name = "NAT"
  }
  depends_on = [aws_internet_gateway.exercise-2-internetgateway]
}

resource "aws_security_group" "webserver" {

    name        = "webserver"
  description = "webserver network traffic"
  vpc_id      = aws_vpc.exercise-2-vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["71.7.187.89/32"]
  }

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "10.0.1.0/28",
      "10.0.2.0/28"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow traffic"
  }
  
}

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "alb network traffic"
  vpc_id      = aws_vpc.exercise-2-vpc.id

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.webserver.id]
  }

  tags = {
    Name = "allow traffic"
  }
}

resource "aws_launch_template" "launchtemplate1" {
  name = "web"

  image_id               = "ami-09d3b3274b6c5d4aa"
  instance_type          = "t2.micro"
  key_name               = "jenkins"
  vpc_security_group_ids = [aws_security_group.webserver.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "WebServer"
    }
  }
user_data = filebase64("user_data.sh")

}

resource "aws_lb" "alb1" {

     name               = "alb1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.subnet_1_public.id, aws_subnet.subnet_2_public.id]

  enable_deletion_protection = false
    tags = {
    Environment = "Prod"
  }
}

resource "aws_alb_target_group" "webserver" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.exercise-2-vpc.id
  
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [aws_subnet.subnet_1_private.id, aws_subnet.subnet_2_private.id]

  desired_capacity = 2
  max_size         = 2
  min_size         = 2

  target_group_arns = [aws_alb_target_group.webserver.arn]

  launch_template {
    id      = aws_launch_template.launchtemplate1.id
    version = "$Latest"
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb1.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }
}

resource "aws_alb_listener_rule" "rule1" {
  listener_arn = aws_alb_listener.front_end.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}