provider "aws" {
  region = "eu-north-1" # Stockholm
}
# ==============================================================================
# 0. PRÉAMBULES
# ==============================================================================
# --- AMI & Account ID dynamiques ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] 
  }
}
data "aws_caller_identity" "current" {}

# --- Key SSH ---
resource "aws_key_pair" "deployer" {
  key_name   = "scalability-key"
  public_key = file("ec2_key.pub") 
}

# ==============================================================================
# 1. RÉSEAU
# ==============================================================================

# --- A. VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "SAB-VPC" }
}

# --- B. Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "SAB-IGW" }
}

# --- C. Subnets Publics ---
data "aws_availability_zones" "available" { state = "available" }

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "SAB-Subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "SAB-Subnet-2" }
}

# --- D. Route Table ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "SAB-Public-RT" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ==============================================================================
# 2. SECURITE
# ==============================================================================

resource "aws_security_group" "web_sg" {
  name        = "SAB_SecurityGroup_Web"
  description = "HTTP et SSH"
  vpc_id      = aws_vpc.main.id 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
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

# ==============================================================================
# 3. IAM & KILL SWITCH
# ==============================================================================

# --- A. Role IAM de la Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "Role_Lambda_KillSwitch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# --- B. Policy IAM pour le Kill Switch ---
resource "aws_iam_policy" "kill_switch_policy" {
  name        = "KillSwitch_EC2"
  description = "Permet de lister et arreter les instances"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "VisualEditor0"
      Effect   = "Allow"
      Action   = [ "ec2:DescribeInstances", "ec2:StopInstances", "ec2:TerminateInstances" ]
      Resource = "*"
    }]
  })
}

# --- C. Attacher les Policies au Role IAM ---
resource "aws_iam_role_policy_attachment" "attach_kill_switch" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.kill_switch_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ==============================================================================
# 4. SNS
# ==============================================================================

# --- A. SNS Topic ---
resource "aws_sns_topic" "budget_alarm" {
  name = "BudgetAlarmTopic"
}

# --- B. Configuration du Topic ---
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.budget_alarm.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Droits propriétaire (Standard)
        Sid    = "Default_Owner_Rights"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.budget_alarm.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        # CRITIQUE Droits AWSBudgets
        Sid    = "AWSBudgets-Notification"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alarm.arn
      }
    ]
  })
}

# ==============================================================================
# 5. LAMBDA FUNCTION   
# ==============================================================================
# --- A. Convertir en ZIP la config Lambda ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# --- B. Créer la Lambda ---
resource "aws_lambda_function" "auto_kill_switch" {
  filename      = "lambda_function.zip"
  function_name = "AutoKillSwitch"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  
  runtime       = "python3.12" 
  
  timeout       = 15
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.attach_kill_switch,
    aws_iam_role_policy_attachment.attach_basic_logs,
    data.archive_file.lambda_zip
  ]
}

# --- C. Permission pour SNS ---
resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_kill_switch.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_alarm.arn
}

# --- D. SNS Subscription ---
resource "aws_sns_topic_subscription" "sub" {
  topic_arn = aws_sns_topic.budget_alarm.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_kill_switch.arn
}

# ==============================================================================
# 6. INSTANCES DE TEST (HORS ASG)
# ==============================================================================
# --- A. Machine Cible (avec TAG) ---
resource "aws_instance" "machine_cible" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1.id 
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = {
    Name    = "Machine Cible"
    Project = "Cible"
  }
}

# --- B. Machine Témoin (sans TAG) ---
resource "aws_instance" "machine_temoin" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1.id 
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = {
    Name = "Machine Temoin"
  }
}

# ==============================================================================
# 5. LOAD BALANCER & AUTO SCALING
# ==============================================================================

# --- A. Target Group ---
resource "aws_lb_target_group" "app_tg" {
  name     = "SAB-TargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id 
  health_check {
    path    = "/"
    matcher = "200"
  }
}

# --- B. Load Balancer ---
resource "aws_lb" "app_lb" {
  name               = "SAB-LoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  
  
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# --- C. Listener ---
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- D. Launch Template ---
resource "aws_launch_template" "app_lt" {
  name_prefix   = "SAB-LT-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" 
  
  key_name      = aws_key_pair.deployer.key_name 
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd stress
              systemctl start httpd
              systemctl enable httpd
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
              echo "<center><h1>Projet Scalability</h1>" > /var/www/html/index.html
              echo "<h3>Serveur ID : <span style='color:red'>$INSTANCE_ID</span></h3>" >> /var/www/html/index.html
              echo "<p>Pour tester le CPU : connectez-vous et lancez 'stress --cpu 1'</p></center>" >> /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "SAB_Instance_Auto"
      Project = "Cible"
    }
  }
}

# --- E. Auto Scaling Group ---
resource "aws_autoscaling_group" "app_asg" {
  name                = "SAB_AutoScalingGroup"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  desired_capacity    = 2
  max_size            = 5 
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}

# =========================================================
#  6. SCALABILITY AUTOMATIQUE (CLOUDWATCH)
# =========================================================
# --- A. Policy UP---
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "SAB_Policy_ScaleUp"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60 
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# --- B. Alarm CPU HIGH ---
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "SAB_Alarm_CPU_High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1" 
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "Alerte si CPU > 50%"
  dimensions = { AutoScalingGroupName = aws_autoscaling_group.app_asg.name }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# --- C. Policy DOWN ---
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "SAB_Policy_ScaleDown"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# --- D. Alarm CPU LOW ---
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "SAB_Alarm_CPU_Low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30"
  dimensions = { AutoScalingGroupName = aws_autoscaling_group.app_asg.name }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

output "website_url" {
  value = "http://${aws_lb.app_lb.dns_name}"
}