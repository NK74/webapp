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

  instances = ["${aws_launch_configuration.launchconfig.webapp.*.id}"]
}

# AUTOSCALING

resource "aws_launch_configuration" "launchconfig" {
  name          = "webapp"
  image_id      = "ami-cb4298b2"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_policy" "autoscaleup" {
  name                   = "Groupe auto scaling"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.autoscalegroup.name}"
}

resource "aws_autoscaling_policy" "autoscaledown" {
  name                   = "Groupe auto scaling"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.autoscalegroup.name}"
}

resource "aws_autoscaling_group" "autoscalegroup" {
  depends_on = ["aws_launch_configuration.launchconfig"]
vpc_zone_identifier = ["subnet-9dd84cc6", "subnet-9dd84cc6"]
  availability_zones        = ["eu-west-1a", "eu-west-1b"]
  name                      = "autoscaling-terraform"
  max_size                  = 3
  min_size                  = 2
  health_check_grace_period = 30
  health_check_type         = "ELB"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.launchconfig.name}"
}

resource "aws_cloudwatch_metric_alarm" "cloudwatchcpu" {
  alarm_name          = "terraform-test-ALARME"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscalegroup.name}"
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.autoscaleup.arn}"]
}
