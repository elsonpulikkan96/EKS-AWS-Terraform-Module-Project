#!/bin/bash

# Script to check compatible EKS addon versions for a given Kubernetes version

CLUSTER_VERSION="${1:-1.35}"
REGION="${2:-us-east-1}"

echo "=========================================="
echo "EKS Addon Version Checker"
echo "=========================================="
echo "Kubernetes Version: ${CLUSTER_VERSION}"
echo "Region: ${REGION}"
echo "=========================================="
echo ""

ADDONS=("vpc-cni" "coredns" "kube-proxy" "aws-ebs-csi-driver" "aws-efs-csi-driver")

for addon in "${ADDONS[@]}"; do
    echo "Checking ${addon}..."
    
    # Get the default/recommended version
    default_version=$(aws eks describe-addon-versions \
        --addon-name "${addon}" \
        --kubernetes-version "${CLUSTER_VERSION}" \
        --region "${REGION}" \
        --query 'addons[0].addonVersions[0].addonVersion' \
        --output text 2>/dev/null)
    
    if [ -n "$default_version" ] && [ "$default_version" != "None" ]; then
        echo "  ✓ Default version: ${default_version}"
        
        # Get all compatible versions
        echo "  Available versions:"
        aws eks describe-addon-versions \
            --addon-name "${addon}" \
            --kubernetes-version "${CLUSTER_VERSION}" \
            --region "${REGION}" \
            --query 'addons[0].addonVersions[*].addonVersion' \
            --output text 2>/dev/null | tr '\t' '\n' | head -5 | sed 's/^/    - /'
    else
        echo "  ✗ No compatible versions found"
    fi
    echo ""
done

echo "=========================================="
echo "Recommendation:"
echo "  - Use default versions (omit version in tfvars)"
echo "  - Or specify exact version from the list above"
echo "=========================================="
