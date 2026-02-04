# Terraform AWS – Scalability & Kill Switch

Ce projet déploie une petite infra AWS pour tester l’auto‑scaling d’EC2 derrière un Application Load Balancer, plus un “kill switch” basé sur une Lambda déclenchée par SNS. 

## Contenu

- VPC avec 2 subnets publics et un security group HTTP/SSH.
- Application Load Balancer + Target Group + Listener HTTP.
- Auto Scaling Group basé sur un Launch Template Amazon Linux (Apache + `stress` + page HTML avec l’ID d’instance).
- 2 instances de test hors ASG (une “cible” taguée, une “témoin”).
- Lambda `AutoKillSwitch` avec rôle IAM, reliée à un topic SNS prévu pour les alertes Budget.
- Alarmes CloudWatch CPU (haute/basse) reliées aux policies de scale up / scale down. 

## Prérequis

- Terraform 1.x, compte AWS configuré.
- `main-1-1.tf`, `ec2_key.pub`, `lambda_function.py` à la racine du projet. 

## Déploiement

```bash
terraform init
terraform plan
terraform apply
