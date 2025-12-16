#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1> Autoscaling Demo - $(hostname) - $(date)</h1>" > /var/www/html/index.html
