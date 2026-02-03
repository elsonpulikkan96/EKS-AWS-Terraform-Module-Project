#!/bin/bash
# Deployment script for EKS infrastructure across AWS accounts
# This ensures Terraform can reach the EKS API endpoint during deployment

set -e

ENV=${1:-dev}
TFVARS_FILE="${ENV}.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    echo "Error: $TFVARS_FILE not found"
    exit 1
fi

echo "=========================================="
echo "Deploying EKS Infrastructure: $ENV"
echo "=========================================="

# Step 1: Initialize Terraform
echo "Step 1: Initializing Terraform..."
terraform init -backend-config=backend.hcl

# Step 2: Select workspace
echo "Step 2: Selecting workspace: $ENV"
terraform workspace select $ENV || terraform workspace new $ENV

# Step 3: Plan
echo "Step 3: Planning infrastructure..."
terraform plan -var-file="$TFVARS_FILE" -out=tfplan

# Step 4: Apply
echo "Step 4: Applying infrastructure..."
terraform apply tfplan

# Step 5: Update kubeconfig
echo "Step 5: Updating kubeconfig..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Step 6: Verify cluster access
echo "Step 6: Verifying cluster access..."
kubectl get nodes

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""
echo "Next steps:"
echo "  - Check Helm releases: helm list -A"
echo "  - Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "  - Get Grafana password: kubectl get secret --namespace prometheus prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
