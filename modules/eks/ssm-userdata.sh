#!/bin/bash
set -e

# Install SSM Agent on Amazon Linux 2 (EKS optimized AMI)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
