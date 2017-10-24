variable "nsg" {
  default = "security-group-webapp"
}

# PROVIDER
provider "aws" {
  region = "eu-west-1"
}

# WEBAPP
resource "aws_instance" "webapp" {
  ami                         = "ami-785db401"
  instance_type               = "t2.micro"
  key_name                    = "Valentin"
  associate_public_ip_address = "true"
  subnet_id                   = "subnet-0648dd5d"
  security_groups             = ["${var.nsg}"]

  tags {
    Name = "WEBAPP-HelloWorld"
  }
}

# SECU GROUP

resource "aws_security_group" "security-group-webapp" {
  name        = "security-group-webapp"
  description = "Filtrage"
  vpc_id      = "vpc-8e6738e9"

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
