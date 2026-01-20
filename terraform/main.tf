terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# KeyPair SSH
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/ec2_key.pub")
}

# ... ton code réseau/security groups identique ...

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"

  key_name               = aws_key_pair.deployer.key_name  # SSH OK !
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(file("${path.module}/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }
}

# ... reste identique CloudWatch/SNS ...

data "aws_instances" "asg_instances" {
  instance_tags = {
    Name = "${var.project_name}-asg-instance"
  }
  instance_state_names = ["running"]
}

output "alb_dns" {
  value = aws_lb.web_alb.dns_name
}

output "asg_public_ips" {
  value = data.aws_instances.asg_instances.public_ips
}
