resource "aws_security_group" "server" {
  name = "${var.cluster_name}-server"

  ingress {
    from_port   = var.server-port
    to_port     = var.server-port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "launch-config" {
  name            = "${var.cluster_name}-launch-config"
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.server.id]

  user_data = templatefile("user-data.sh", {
    server_port = var.server-port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })
  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Allow the webserver to read outputs from the db tier
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

resource "aws_autoscaling_group" "example-asg" {
  name                 = "${var.cluster_name}-asg"
  launch_configuration = aws_launch_configuration.launch-config.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-terraform-asg"
    propagate_at_launch = true
  }
}

resource "aws_lb" "alb" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb-sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"


    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb-sg" {
  name = "${var.cluster_name}-alb-sg"

  # Allow inbound HTTP requests
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allows incoming traffic from anywhere to port 80"
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  # Allow all outbound requests
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allows all outbound traffic so alb can perform health checks"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "${var.cluster_name}-asg"
  port     = var.server-port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}


