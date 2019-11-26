provider "aws" {
	region = "us-east-1"
}


resource "aws_launch_configuration" "example" {
	image_id = "ami-04763b3055de4860b"
	instance_type = "t2.micro"
	associate_public_ip_address = true
	security_groups = [aws_security_group.sec-group.id]
	user_data= <<-EOF
				#!/bin/bash
				echo "Hello, world" > index.html
				nohup busybox httpd -f -p 8080 & 
				EOF

	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "example"{
	launch_configuration = aws_launch_configuration.example.name
	vpc_zone_identifier = data.aws_subnet_ids.default.ids
	target_group_arns = [aws_lb_target_group.asg.arn]
	min_size = 2
	max_size = 10
	tag {
		key = "Name"
		value = "terraform-asg-example"
		propagate_at_launch = true
	}

}

data "aws_vpc" "default" {
	default = true
}

data "aws_subnet_ids" "default" {
	vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "sec-group" {
	ingress {
		from_port = 8080
		to_port = 8080
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}


resource "aws_lb" "example" {
	name = "terraform-asg-example"
	load_balancer_type = "application"
	security_groups = [aws_security_group.alb.id]
	subnets = data.aws_subnet_ids.default.ids
}

resource "aws_lb_listener" "http" {
	load_balancer_arn = aws_lb.example.arn
	port = 8080
	protocol = "HTTP"

	default_action {
		type = "fixed-response"
		fixed_response {
			content_type = "text/plain"
			message_body = "English 404: page not found"
			status_code = 404
		}
	}
}

resource "aws_lb_listener_rule" "asg" {
	listener_arn = aws_lb_listener.http.arn 
	priority =  100

	condition {
		field = "path-pattern"
		values = ["*"]

	}

	action {
		type = "forward"
		target_group_arn = aws_lb_target_group.asg.arn
	}
}

resource "aws_lb_target_group" "asg" {
	name = "terraform-asg-example"
	port = 8080
	protocol = "HTTP"
	vpc_id = data.aws_vpc.default.id

	health_check {
		path = "/"	
		protocol = "HTTP"
		matcher = "200"
		interval = 15
		timeout = 3
		healthy_threshold = 2
		unhealthy_threshold = 2
	}

}	

resource "aws_security_group" "alb" {
	ingress {
		from_port = 8080
		to_port = 8080
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}


output "alb_dns_name" {
	value = aws_lb.example.dns_name
	description = "DNS of the application load balancer"
}


















