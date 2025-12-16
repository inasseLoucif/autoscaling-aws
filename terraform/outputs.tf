output "alb_dns_name" {
  description = "URL du load balancer"
  value       = aws_lb.web_alb.dns_name
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.web_asg.name
}
