#!/bin/bash
set -e

echo "=========================================="
echo "Fixing EKS Endpoint Access"
echo "=========================================="

# Get cluster name from tfvars
CLUSTER_NAME="production-prod-eks-cluster"
REGION="us-east-1"

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"

# Update cluster endpoint access
echo "Enabling public endpoint access..."
aws eks update-cluster-config \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="0.0.0.0/0",endpointPrivateAccess=true

echo ""
echo "Waiting for cluster update to complete (this takes 5-10 minutes)..."
aws eks wait cluster-active --name "$CLUSTER_NAME" --region "$REGION"

echo ""
echo "=========================================="
echo "Endpoint access updated successfully!"
echo "=========================================="
echo ""
echo "Verify with:"
echo "  aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig'"
echo ""
echo "Now run: terraform apply -var-file=prod.tfvars"
