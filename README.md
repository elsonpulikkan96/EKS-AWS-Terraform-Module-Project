# EKS-AWS-Terraform-Module-Project


## For more projects, check out  
[https://elsondevops.cloud](https://elsondevops.cloud)

[https://github.com/elsonpulikkan96](https://github.com/elsonpulikkan96)

## 1. Terraform Installation

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform packer git jq unzip
```

## 2. AWS CLI Installation

Refer: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
sudo apt install -y unzip jq
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws configure
```

## 3. kubectl installtion Configuration

```bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

sudo apt-get update
sudo apt-get install -y kubectl bash-completion

# Enable kubectl auto-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
```

## eksctl Installtion

```bash
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

# Install bash completion
sudo apt-get install -y bash-completion

# Enable eksctl auto-completion
echo 'source <(eksctl completion bash)' >> ~/.bashrc
echo 'alias e=eksctl' >> ~/.bashrc
echo 'complete -F __start_eksctl e' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
```

## 4. Helm Installation

Refer: [Helm Installation Guide](https://helm.sh/docs/intro/install/)

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

# Apply changes immediately
source ~/.bashrc
```


```bash
terraform destroy -var-file="dev.tfvars" -auto-approve
terraform destroy -var-file="stage.tfvars" -auto-approve
terraform destroy -var-file="prod.tfvars" -auto-approve
``` 


## 5. EKS Cluster Setup

### Configure AWS Credentials
```bash
aws configure
aws sts get-caller-identity
```

### Setup Remote State Backend (First Time Only)

Before running Terraform, set up the remote state backend:

```bash
# Create S3 bucket and DynamoDB table for state management
./setup-backend.sh

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl
```

**Note**: The setup script automatically creates account-specific resources:
- S3 Bucket: `eks-terraform-state-<AWS_ACCOUNT_ID>`
- DynamoDB Table: `eks-terraform-locks-<AWS_ACCOUNT_ID>`
- Backend config file: `backend.hcl` (auto-generated)

The backend uses workspace-based state isolation:
- Dev: `s3://eks-terraform-state-<ACCOUNT_ID>/env:/dev/eks-cluster/terraform.tfstate`
- Stage: `s3://eks-terraform-state-<ACCOUNT_ID>/env:/stage/eks-cluster/terraform.tfstate`
- Prod: `s3://eks-terraform-state-<ACCOUNT_ID>/env:/prod/eks-cluster/terraform.tfstate`

## 6. Terraform Workspace Management

This project uses Terraform workspaces to manage multiple environments (dev, stage, prod).

### List available workspaces
```bash
terraform workspace list
```

### Switch between workspaces
```bash
# Switch to dev workspace
terraform workspace select dev

# Switch to stage workspace
terraform workspace select stage

# Switch to prod workspace
terraform workspace select prod

# Switch to default workspace
terraform workspace select default
```

### Create new workspace (if needed)
```bash
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
```

## 7. Terraform Apply

### For Dev Environment
```bash
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars" -auto-approve
```

### For Stage Environment
```bash
terraform workspace select stage
terraform plan -var-file="stage.tfvars"
terraform apply -var-file="stage.tfvars" -auto-approve
```

### For Prod Environment
```bash
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars" -auto-approve
```

## 8. Install EKS Addons version check
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm search repo eks/aws-load-balancer-controller --versions
helm list -A
```

## 9. Install EKS Addons argo-cd version check
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm search repo argo/argo-cd --versions
helm list -A
```

## 10. Install EKS Addons prometheus version check
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm search repo prometheus-community/kube-prometheus-stack --versions
helm list -A
```

## 11. update the kubeconfig
```bash
aws eks update-kubeconfig --name testing-spectrio-test-eks-cluster --region us-east-1
```

## 12. get the argocd server url
```bash
kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'
```

## 13. get the argocd admin password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 14. get the prometheus admin password
```bash
kubectl get secret --namespace prometheus prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

## 15. get the prometheus grafana image
```bash
helm list -n prometheus
kubectl get pods -n prometheus -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].spec.containers[*].image}'
```

## 16. reset the prometheus grafana admin password
```bash 
kubectl exec --namespace prometheus -it $(kubectl get pods --namespace prometheus -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}") -- grafana-cli admin reset-admin-password Abcd@1234
```

## 17. Delete the Deployments
```bash
kubectl delete -f .
```

## 18. Destroy the infrastructure

### For Dev Environment
```bash
terraform workspace select dev
terraform destroy -var-file="dev.tfvars" -auto-approve
```

### For Stage Environment
```bash
terraform workspace select stage
terraform destroy -var-file="stage.tfvars" -auto-approve
```

### For Prod Environment
```bash
terraform workspace select prod
terraform destroy -var-file="prod.tfvars" -auto-approve
```

### Alternative: Delete EKS cluster using eksctl
```bash
eksctl delete cluster --name testing-spectrio-test-eks-cluster --region us-east-1
```
