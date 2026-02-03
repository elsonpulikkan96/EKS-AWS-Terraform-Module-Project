# EKS AWS Terraform Module Project

Complete infrastructure-as-code solution for deploying production-ready Amazon EKS clusters with automated backend setup, SSH key management, SSM access, and comprehensive monitoring.

## For More Projects
- [https://elsondevops.cloud](https://elsondevops.cloud)
- [https://github.com/elsonpulikkan96](https://github.com/elsonpulikkan96)

---

## Table of Contents

1. [Prerequisites Installation](#1-prerequisites-installation)
2. [Backend Setup (First Time Only)](#2-backend-setup-first-time-only)
3. [Workspace Management](#3-workspace-management)
4. [Infrastructure Deployment](#4-infrastructure-deployment)
5. [SSH Key Management](#5-ssh-key-management)
6. [SSM Access Configuration](#6-ssm-access-configuration)
7. [EKS Cluster Access](#7-eks-cluster-access)
8. [Helm & Add-ons](#8-helm--add-ons)
9. [Monitoring & Observability](#9-monitoring--observability)
10. [Tagging Strategy](#10-tagging-strategy)
11. [Troubleshooting](#11-troubleshooting)
12. [Common Issues & Solutions](#12-common-issues--solutions)
13. [Cleanup & Destroy](#13-cleanup--destroy)
14. [Architecture Decisions](#14-architecture-decisions)

---

## 1. Prerequisites Installation

### Terraform Installation

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform packer git jq unzip
```

### AWS CLI Installation

```bash
sudo apt install -y unzip jq
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

Refer: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### kubectl Installation

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl bash-completion

# Enable kubectl auto-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

### eksctl Installation

```bash
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

# Enable eksctl auto-completion
echo 'source <(eksctl completion bash)' >> ~/.bashrc
echo 'alias e=eksctl' >> ~/.bashrc
echo 'complete -F __start_eksctl e' >> ~/.bashrc
source ~/.bashrc
```

### Helm Installation

```bash
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm bash-completion

# Enable Helm auto-completion
echo 'source <(helm completion bash)' >> ~/.bashrc
echo 'alias h=helm' >> ~/.bashrc
echo 'complete -F __start_helm h' >> ~/.bashrc
source ~/.bashrc
```

Refer: [Helm Installation Guide](https://helm.sh/docs/intro/install/)

---

## 2. Backend Setup (First Time Only)

This project uses a centralized S3 backend with DynamoDB state locking for secure, collaborative infrastructure management.

### Backend Architecture

**Components:**
- **S3 Bucket**: `spectrio-eks-terraform-state` (versioning enabled, encrypted)
- **DynamoDB Table**: `spectrio-eks-terraform-locks` (state locking)
- **Workspace Isolation**: Separate state files per environment

**State File Organization:**
```
s3://spectrio-eks-terraform-state/
├── eks-cluster/terraform.tfstate                    # default workspace
└── env:/
    ├── dev/eks-cluster/terraform.tfstate           # dev workspace
    ├── stage/eks-cluster/terraform.tfstate         # stage workspace
    └── prod/eks-cluster/terraform.tfstate          # prod workspace
```

### Setup Steps

```bash
# 1. Configure AWS credentials
aws configure
aws sts get-caller-identity

# 2. Create backend infrastructure (S3 + DynamoDB)
./setup-backend.sh

# 3. Initialize Terraform with backend
terraform init -migrate-state

# 4. Create workspaces
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
```

### Backend Security Features

- ✅ **Versioning**: 90-day retention for state file versions
- ✅ **Encryption**: AES256 server-side encryption
- ✅ **Public Access**: Completely blocked
- ✅ **TLS Enforcement**: HTTPS-only access
- ✅ **State Locking**: Prevents concurrent modifications
- ✅ **Point-in-Time Recovery**: DynamoDB backup enabled

### Verify Backend

```bash
# Check current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Verify remote state
aws s3 ls s3://spectrio-eks-terraform-state/eks-cluster/ --recursive
```

---

## 3. Workspace Management

Terraform workspaces provide isolated state management for multiple environments.

### List Workspaces

```bash
terraform workspace list
```

### Switch Workspaces

```bash
# Switch to dev
terraform workspace select dev

# Switch to stage
terraform workspace select stage

# Switch to prod
terraform workspace select prod

# Switch to default
terraform workspace select default
```

### Create New Workspace

```bash
terraform workspace new <workspace-name>
```

---

## 4. Infrastructure Deployment

### Important: Cross-Account Reusability

This code is designed for **reusability across different AWS accounts**. The EKS cluster API endpoint is configured with:

- **Public Access Enabled**: Allows Terraform to deploy Helm charts from anywhere
- **Public Access CIDRs**: Configurable per environment (default: `0.0.0.0/0` for dev/stage)
- **Private Access Enabled**: Allows bastion and worker nodes to communicate via private endpoint

**Why this matters**: When deploying the bastion and EKS cluster in the same Terraform run, Terraform needs to reach the EKS API endpoint to install Helm charts BEFORE the bastion exists. Public endpoint access solves this chicken-and-egg problem.

### Quick Deploy (Recommended)

```bash
# Deploy dev environment
./deploy.sh dev

# Deploy stage environment
./deploy.sh stage

# Deploy prod environment (requires VPN/bastion access)
./deploy.sh prod
```

### Manual Deployment

### Dev Environment

```bash
# Initialize backend (if not already done)
terraform init -backend-config=backend.hcl

# Select workspace
terraform workspace select dev

# Plan and apply
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars" -auto-approve
```

### Stage Environment

```bash
# Initialize backend (if not already done)
terraform init -backend-config=backend.hcl

# Select workspace
terraform workspace select stage

# Plan and apply
terraform plan -var-file="stage.tfvars"
terraform apply -var-file="stage.tfvars" -auto-approve
```

### Prod Environment

```bash
# Initialize backend (if not already done)
terraform init -backend-config=backend.hcl

# Select workspace
terraform workspace select prod

# Plan and apply
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars" -auto-approve
```

---

## 5. SSH Key Management

### Automatic Key Generation

SSH keys are **automatically generated** by Terraform with account-specific naming for portability across AWS accounts.

**Key Naming Convention:** `eks-<environment>-<aws_account_id>`

**Examples:**
- Dev: `eks-testing-123456789012`
- Stage: `eks-staging-123456789012`
- Prod: `eks-production-123456789012`

### How It Works

When you run `terraform apply`:
1. Generates a new RSA 4096-bit key pair
2. Creates the key pair in AWS EC2
3. Saves the private key locally as `eks-<env>-<account_id>.pem` with 0400 permissions

### View Key Information

```bash
# Show key name
terraform output ssh_key_name

# Show private key path
terraform output ssh_private_key_path

# Get bastion public IP
terraform output bastion_public_ip
```

### SSH to Bastion

```bash
# Using generated key
ssh -i eks-staging-123456789012.pem ubuntu@<bastion_ip>
```

### Security Notes

- ✅ Private keys auto-saved locally with proper permissions (0400)
- ✅ Keys excluded from git via `.gitignore`
- ✅ Account-specific naming prevents conflicts
- ✅ Environment-specific isolation
- ✅ Proper tagging for management

---

## 6. SSM Access Configuration

Both **Bastion Host** and **EKS Worker Nodes** are configured with AWS Systems Manager (SSM) Session Manager for secure shell access.

### What's Configured

#### ✅ Bastion Host (Ubuntu)
- **SSM Agent**: Installed via snap in `bastion_script.sh`
- **IAM Policy**: `AmazonSSMManagedInstanceCore`
- **Installation**: `snap install amazon-ssm-agent --classic`

#### ✅ EKS Worker Nodes (Amazon Linux 2)
- **SSM Agent**: **PRE-INSTALLED** in EKS Optimized AMI (no custom installation needed)
- **IAM Policy**: `AmazonSSMManagedInstanceCore` attached to node role
- **Note**: SSM agent has been included in EKS Optimized AMI since 2020
- **Applied To**: Both on-demand and spot node groups

### Benefits of SSM Session Manager

1. **No SSH Keys Required**: Access instances without managing SSH keys
2. **No Inbound Ports**: No need to open port 22 in security groups
3. **Audit Trail**: All sessions logged in CloudTrail
4. **IAM-Based Access**: Control access via IAM policies
5. **Session Recording**: Optional session logging to S3
6. **Port Forwarding**: Tunnel to private resources

### Prerequisites

Install the Session Manager plugin:

```bash
# macOS
brew install --cask session-manager-plugin

# Ubuntu/Debian
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb

# Verify installation
session-manager-plugin
```

### Connect to Bastion Host

```bash
# List available instances
aws ssm describe-instance-information --region us-east-1

# Get bastion instance ID
BASTION_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bastion-stage" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-east-1)

# Start SSM session
aws ssm start-session --target $BASTION_ID --region us-east-1
```

### Connect to EKS Worker Node

```bash
# List EKS worker nodes
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/staging-spectrio-stage-eks-cluster,Values=owned" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table \
  --region us-east-1

# Get worker node instance ID
NODE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/staging-spectrio-stage-eks-cluster,Values=owned" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-east-1)

# Start SSM session
aws ssm start-session --target $NODE_ID --region us-east-1
```

### Port Forwarding

```bash
# Forward local port 8080 to remote port 80
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}' \
  --region us-east-1
```

### Verify SSM Agent Status

**On Bastion (Ubuntu):**
```bash
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
```

**On Worker Nodes (Amazon Linux 2):**
```bash
sudo systemctl status amazon-ssm-agent
```

### Check Instance Registration

```bash
# List all SSM-managed instances
aws ssm describe-instance-information \
  --region us-east-1 \
  --output table
```

---

## 7. EKS Cluster Access

### Update kubeconfig

```bash
aws eks update-kubeconfig --name testing-spectrio-test-eks-cluster --region us-east-1
```

### Verify Cluster Access

```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

---

## 8. Helm & Add-ons

### Check Installed Helm Charts

```bash
helm list -A
```

### AWS Load Balancer Controller

```bash
# Add EKS Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Check available versions
helm search repo eks/aws-load-balancer-controller --versions
```

### ArgoCD

```bash
# Add Argo Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Check available versions
helm search repo argo/argo-cd --versions

# Get ArgoCD server URL
kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Prometheus & Grafana

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

# Check available versions
helm search repo prometheus-community/kube-prometheus-stack --versions
```

---

## 9. Monitoring & Observability

### Grafana Access

```bash
# Get Grafana admin password
kubectl get secret --namespace prometheus prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Get Grafana image version
kubectl get pods -n prometheus -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].spec.containers[*].image}'

# Reset Grafana admin password
kubectl exec --namespace prometheus -it $(kubectl get pods --namespace prometheus -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}") -- grafana-cli admin reset-admin-password Abcd@1234
```

### Port Forward to Grafana

```bash
kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80
# Access at http://localhost:3000
```

### Port Forward to ArgoCD

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access at https://localhost:8080
```

---

## 10. Tagging Strategy

All AWS resources are automatically tagged with `terraform = "true"` via provider-level default tags.

### Tagged Resources (21+ Types)

**VPC Module:**
- VPC, Subnets (public/private), Internet Gateway, NAT Gateway, Elastic IP, Route Tables

**Security Group Module:**
- EKS Cluster Security Group, Bastion Security Group

**EKS Module:**
- EKS Cluster, On-Demand Node Group, Spot Node Group

**IAM Module:**
- All IAM Roles and Policies

**Bastion Module:**
- Bastion EC2 Instance

**Additional Tags:**
- `Name` - Resource-specific name
- `Env` - Environment (testing/staging/production)
- Custom tags from tfvars

### Tag Implementation

Tags are applied via:
1. **Provider-level default tags** in `versions.tf`
2. **Common tags** in `main.tf` locals
3. **Resource-specific tags** merged with common tags

### Verify Tags

```bash
# Check EC2 instances
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:terraform,Values=true" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check EBS volumes
aws ec2 describe-volumes \
  --region us-east-1 \
  --filters "Name=tag:terraform,Values=true" \
  --query 'Volumes[*].[VolumeId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

---

## 11. Troubleshooting

### State Lock Issues

```bash
# View lock information
aws dynamodb get-item \
  --table-name spectrio-eks-terraform-locks \
  --key '{"LockID":{"S":"spectrio-eks-terraform-state/env:/dev/eks-cluster/terraform.tfstate-md5"}}'

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

### Re-initialize Backend

```bash
terraform init -reconfigure
```

### SSM Connection Issues

```bash
# Check instance connectivity
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=<instance-id>" \
  --query 'InstanceInformationList[0].PingStatus' \
  --region us-east-1

# View SSM agent logs (Ubuntu)
sudo journalctl -u snap.amazon-ssm-agent.amazon-ssm-agent.service -f

# View SSM agent logs (Amazon Linux 2)
sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log
```

### EKS Access Issues

```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region us-east-1

# Check cluster status
aws eks describe-cluster --name <cluster-name> --region us-east-1

# Verify IAM authentication
kubectl auth can-i get pods --all-namespaces
```

---

## 12. Common Issues & Solutions

### Issue 1: "Kubernetes cluster unreachable: dial tcp 10.x.x.x:443: i/o timeout"

**Root Cause:**
Terraform is trying to reach the EKS API endpoint but getting a private IP that's unreachable from your current location.

**Why This Happens:**
When both `endpoint_private_access = true` and `endpoint_public_access = true` are enabled, AWS EKS DNS resolution returns:
- **Private IP** to clients within the VPC
- **Public IP** to clients outside the VPC

However, if you're running Terraform from a machine that's in a different VPC (without peering/transit gateway) or behind a NAT that AWS doesn't recognize as "external", you may get the private IP but can't route to it.

**Solution:**
Explicitly configure `public_access_cidrs` in your tfvars:

```hcl
# Dev/Stage: Allow from anywhere
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]

# Production: Restrict to specific IPs
public_access_cidrs = ["203.0.113.0/24"]  # Your office/VPN IP

# Or private only (requires bastion deployment)
endpoint_public_access = false
public_access_cidrs    = []
```

**Quick Fix:**
```bash
# 1. Update tfvars
echo 'public_access_cidrs = ["0.0.0.0/0"]' >> dev.tfvars

# 2. Update cluster
terraform apply -var-file=dev.tfvars -target=module.eks

# 3. Wait 2-3 minutes for endpoint update

# 4. Retry full deployment
terraform apply -var-file=dev.tfvars
```

### Issue 2: "User data was not in the MIME multipart format"

**Root Cause:**
Custom user data in launch templates must be in MIME multipart format when used with EKS node groups.

**Solution:**
**DON'T add custom user data!** SSM Agent is pre-installed in EKS Optimized AMI since 2020.

```hcl
# CORRECT: No user data needed
resource "aws_launch_template" "ondemand" {
  name_prefix = "${var.cluster_name}-ondemand-"
  key_name    = var.node_key_name
  
  # Note: SSM Agent is pre-installed in EKS Optimized AMI
  # No custom user_data needed - EKS handles bootstrap automatically
}
```

**Why This Works:**
- ✅ SSM Agent pre-installed in EKS Optimized AMI
- ✅ IAM policy `AmazonSSMManagedInstanceCore` attached to node role
- ✅ EKS automatically bootstraps nodes
- ✅ No manual installation needed

### Issue 3: Data Source "kubernetes_service_v1" Not Found

**Root Cause:**
Data sources are read during plan phase before services are created.

**Solution:**
Already fixed with explicit `time_sleep` resources and `depends_on` in helm module.

### Issue 4: Provider Initialization Fails on Fresh Deployment

**Root Cause:**
Kubernetes/Helm providers try to connect to cluster that doesn't exist yet.

**Solution:**
Already fixed with `try()` functions in provider.tf to handle missing values gracefully.

### Issue 5: Workspace vs Environment Mismatch

**Problem:**
Running `terraform workspace select prod` with `dev.tfvars` creates mismatched resources.

**Solution:**
Always verify workspace matches tfvars:

```bash
# Check current workspace
terraform workspace show

# Ensure it matches your tfvars
terraform workspace select dev
terraform apply -var-file=dev.tfvars
```

---

## 13. Cleanup & Destroy

### Delete Kubernetes Deployments

```bash
kubectl delete -f .
```

### Destroy Infrastructure

#### Dev Environment
```bash
terraform workspace select dev
terraform destroy -var-file="dev.tfvars" -auto-approve
```

#### Stage Environment
```bash
terraform workspace select stage
terraform destroy -var-file="stage.tfvars" -auto-approve
```

#### Prod Environment
```bash
terraform workspace select prod
terraform destroy -var-file="prod.tfvars" -auto-approve
```

### Alternative: Delete EKS Cluster Using eksctl

```bash
eksctl delete cluster --name testing-spectrio-test-eks-cluster --region us-east-1
```

### Cleanup Backend (Caution!)

⚠️ **Warning**: Only do this when decommissioning the entire project!

```bash
# Delete all state files
aws s3 rm s3://spectrio-eks-terraform-state --recursive

# Delete S3 bucket
aws s3api delete-bucket --bucket spectrio-eks-terraform-state --region us-east-1

# Delete DynamoDB table
aws dynamodb delete-table --table-name spectrio-eks-terraform-locks --region us-east-1
```

---

## 14. Architecture Decisions

### Why Public Endpoint Access?

**Design Decision:** Enable public endpoint access for dev/stage environments to allow Terraform deployment from anywhere.

**The Challenge:**
When deploying bastion + EKS + Helm in a single Terraform run:
1. Helm/Kubernetes providers need to reach EKS API endpoint
2. Bastion doesn't exist yet during first deployment
3. Running Terraform from outside the VPC requires public endpoint access

**The Solution:**
```hcl
# Dev/Stage: Public access enabled
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]

# Production: Private only (deploy from bastion or CI/CD in VPC)
endpoint_private_access = true
endpoint_public_access  = false
```

**Benefits:**
- ✅ Deploy from any AWS account
- ✅ Deploy from any location (laptop, CI/CD, bastion)
- ✅ No VPN required for dev/stage
- ✅ Faster iteration cycles
- ✅ True cross-account reusability

**Security:**
- Private endpoint always enabled for internal communication
- Public access can be restricted by CIDR
- Production uses private-only access
- All API calls authenticated via IAM

### Why No Custom User Data?

**Design Decision:** Don't add custom user data to EKS node launch templates.

**The Reality:**
- SSM Agent is **pre-installed** in EKS Optimized AMI since 2020
- EKS automatically handles node bootstrapping
- Custom user data requires MIME multipart format
- Adding unnecessary user data increases complexity

**What We Do Instead:**
- Attach IAM policy: `AmazonSSMManagedInstanceCore`
- Let EKS handle bootstrap automatically
- Use launch templates only for SSH keys, tags, and EBS volumes

### Why Separate Security Groups?

**Design Decision:** Use VPC CIDR-based rules instead of security group references.

**The Problem with SG References:**
```hcl
# This creates circular dependency
ingress {
  security_groups = [aws_security_group.bastion-sg.id]
}
```

**Our Approach:**
```hcl
# Use VPC CIDR instead
ingress {
  cidr_blocks = [var.vpc_cidr]
}
```

**Benefits:**
- ✅ No circular dependencies
- ✅ Simpler resource graph
- ✅ Works with external access patterns
- ✅ More flexible for CI/CD

### Why try() in Providers?

**Design Decision:** Use `try()` functions in Kubernetes/Helm provider configuration.

**The Problem:**
Providers are initialized **before** resources are created. If cluster doesn't exist:
- `module.eks.cluster_endpoint` is null
- Provider initialization fails
- Terraform can't proceed

**The Solution:**
```hcl
provider "kubernetes" {
  host = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
}
```

**Benefits:**
- ✅ Graceful handling of missing cluster
- ✅ Works on fresh deployments
- ✅ Works during destroy operations
- ✅ No manual intervention needed

### Why Explicit Waits?

**Design Decision:** Add `time_sleep` resources between Helm releases and data sources.

**The Problem:**
- Helm releases create Kubernetes resources asynchronously
- Data sources try to read resources immediately
- Race condition causes random failures

**The Solution:**
```hcl
resource "time_sleep" "wait_for_prometheus" {
  depends_on      = [helm_release.prometheus-helm]
  create_duration = "120s"
}

data "kubernetes_service_v1" "prometheus_server" {
  depends_on = [time_sleep.wait_for_prometheus]
}
```

**Benefits:**
- ✅ Reliable deployments
- ✅ No random failures
- ✅ Predictable behavior
- ✅ Works across all AWS accounts

### Why Workspace + Environment Variable?

**Design Decision:** Use both Terraform workspaces AND environment variable.

**The Approach:**
- Workspaces: Isolate state files
- Environment variable: Control resource naming and configuration

**Why Both?**
```hcl
# Workspace: State isolation
terraform workspace select dev

# Environment variable: Resource naming
cluster_name = "${var.env}-${var.cluster_name}"
```

**Benefits:**
- ✅ State isolation per environment
- ✅ Consistent naming regardless of workspace
- ✅ Prevents workspace/config mismatch
- ✅ Clear environment identification

### Critical Fixes Applied

| Issue | Impact | Solution |
|-------|--------|----------|
| Provider dependency on non-existent cluster | 🔴 Breaks fresh deployments | Added `try()` functions |
| Security group circular dependency | 🔴 Fragile resource graph | Use VPC CIDR instead of SG refs |
| Data source race conditions | 🟠 Random failures | Added explicit `time_sleep` waits |
| Default public_access_cidrs = 0.0.0.0/0 | 🟡 Security risk | Removed default, added validation |
| Workspace vs env mismatch | 🟡 Wrong naming | Use `var.env` consistently |
| Helm timeout inconsistency | 🟢 Unpredictable timeouts | Standardized to 600-2000s |

---

## Project Structure

```
.
├── README.md                          # This file
├── backend.tf                         # Backend configuration
├── keypair.tf                         # Auto-generated SSH keys
├── main.tf                            # Root module
├── outputs.tf                         # Output values
├── provider.tf                        # AWS provider config
├── variables.tf                       # Input variables
├── versions.tf                        # Provider versions & default tags
├── dev.tfvars                         # Dev environment config
├── stage.tfvars                       # Stage environment config
├── prod.tfvars                        # Prod environment config
├── setup-backend.sh                   # Backend setup script
├── bastion_script.sh                  # Bastion userdata
├── modules/
│   ├── bastion/                       # Bastion host module
│   ├── eks/                           # EKS cluster module
│   │   └── ssm-userdata.sh           # Worker node SSM setup
│   ├── helm/                          # Helm charts module
│   ├── iam/                           # IAM roles & policies
│   ├── service-account/               # K8s service accounts
│   ├── sg/                            # Security groups
│   └── vpc/                           # VPC networking
└── .gitignore                         # Git ignore rules
```

---

## Key Features

✅ **Automated Backend Setup**: Single script creates S3 + DynamoDB backend  
✅ **Workspace Isolation**: Separate state files per environment  
✅ **Auto-Generated SSH Keys**: Account-specific key naming  
✅ **SSM Access**: Secure shell access without SSH keys  
✅ **Comprehensive Tagging**: All resources tagged with `terraform=true`  
✅ **Multi-Environment**: Dev, Stage, Prod configurations  
✅ **Monitoring Stack**: Prometheus + Grafana pre-configured  
✅ **GitOps Ready**: ArgoCD installed and configured  
✅ **Load Balancer Controller**: AWS ALB controller integrated  
✅ **Security Best Practices**: Encryption, versioning, state locking  

---

## Important Notes

### State Management
- ✅ State files stored in S3 (not locally)
- ✅ Each workspace has isolated state
- ✅ State locking prevents concurrent modifications
- ✅ Versioning enabled (90-day retention)
- ✅ Encryption at rest enabled

### Security
- ❌ Never commit state files to git
- ❌ Never manually edit state files
- ❌ Never force-unlock without coordination
- ✅ Use SSM Session Manager for instance access
- ✅ All resources tagged for governance
- ✅ IAM-based access control

### Cost Optimization
- Spot instances for non-critical workloads
- Auto-scaling enabled for node groups
- S3 lifecycle policies for old state versions
- DynamoDB pay-per-request billing

---

## Support & Documentation

- **AWS EKS**: https://docs.aws.amazon.com/eks/
- **Terraform**: https://www.terraform.io/docs
- **Helm**: https://helm.sh/docs/
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Prometheus**: https://prometheus.io/docs/

---

## License

This project is open source and available for educational and commercial use.

---

## Author

**Elson Pulikkan**
- Website: [https://elsondevops.cloud](https://elsondevops.cloud)
- GitHub: [https://github.com/elsonpulikkan96](https://github.com/elsonpulikkan96)
