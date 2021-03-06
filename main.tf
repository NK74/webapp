# DECLARATION S3
terraform {
  backend "s3" {
    bucket = "backend.terraform"
    key    = "webapp/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config {
    bucket = "backend.terraform"
    key    = "vpc/terraform.tfstate"
    region = "eu-west-1"
  }
}

# TEMPLATE USERDATA
data "template_file" "user_data" {
  template = "${file("userdata.tpl")}"
}

# PROVIDER : AWS
provider "aws" {
  region = "eu-west-1"
}

# DECLARATION INSTANCE
resource "aws_instance" "webapp" {
  count                       = "2"
  ami                         = "ami-785db401"
  instance_type               = "t2.micro"
  key_name                    = "Valentin"
  associate_public_ip_address = "true"
  subnet_id                   = "${element(data.terraform_remote_state.infrastructure.subnet_all, count.index)}"
  security_groups             = ["${aws_security_group.security-group-webapp.id}"]
  user_data                   = "${data.template_file.user_data.rendered}"

  tags {
    Name = "WEBAPP-${count.index}"
  }
}

# DECLARATION SECURITY GROUP
resource "aws_security_group" "security-group-webapp" {
  name        = "security-group-webapp"
  description = "Filtrage"
  vpc_id      = "${data.terraform_remote_state.infrastructure.vpc_id}"

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

  tags {
    Name = "WEBAPP-SecuGroup"
  }
}

# DECLARATION ELB
resource "aws_elb" "elb" {
  name            = "elb-infra"
  subnets         = ["${data.terraform_remote_state.infrastructure.subnet_all}"]
  security_groups = ["${aws_security_group.security-group-webapp.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    target              = "HTTP:80/"
    interval            = 5
  }

  instances = ["${aws_instance.webapp.*.id}"]
}
