# EKS Addon Version Issue - Fix Guide

## Problem
The `aws-ebs-csi-driver` addon was timing out during creation due to version incompatibility with EKS 1.35.

## Changes Made

### 1. Updated EKS Module (`modules/eks/main.tf`)
- Added 30-minute timeout for addon creation
- Added conflict resolution strategy (`OVERWRITE`)
- Added service account role for EBS CSI driver
- Made addon version optional (uses AWS default if not specified)

### 2. Updated Variables
- Made `version` field optional in addon object type
- Allows AWS to auto-select compatible versions

### 3. Updated tfvars Files (dev/stage/prod)
- Removed explicit version for `aws-ebs-csi-driver`
- AWS will now auto-select the compatible version for EKS 1.35

## On Bastion - Immediate Actions

### Step 1: Delete the Stuck Addon
```bash
aws eks delete-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1

# Wait for deletion
aws eks describe-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 2>&1 | grep -q "ResourceNotFoundException" && echo "Addon deleted successfully"
```

### Step 2: Copy Updated Files to Bastion
```bash
# From your local machine
scp /Users/elsonpealias/kiro/EKS-AWS-Terraform-Module-Project/modules/eks/main.tf \
    root@tf-bastion-eks-project:~/EKS-AWS-Terraform-Module-Project/modules/eks/

scp /Users/elsonpealias/kiro/EKS-AWS-Terraform-Module-Project/modules/eks/variables.tf \
    root@tf-bastion-eks-project:~/EKS-AWS-Terraform-Module-Project/modules/eks/

scp /Users/elsonpealias/kiro/EKS-AWS-Terraform-Module-Project/variables.tf \
    root@tf-bastion-eks-project:~/EKS-AWS-Terraform-Module-Project/

scp /Users/elsonpealias/kiro/EKS-AWS-Terraform-Module-Project/dev.tfvars \
    root@tf-bastion-eks-project:~/EKS-AWS-Terraform-Module-Project/

scp /Users/elsonpealias/kiro/EKS-AWS-Terraform-Module-Project/check-addon-versions.sh \
    root@tf-bastion-eks-project:~/EKS-AWS-Terraform-Module-Project/
```

### Step 3: Check Compatible Versions (Optional)
```bash
chmod +x check-addon-versions.sh
./check-addon-versions.sh 1.35 us-east-1
```

### Step 4: Re-run Terraform Apply
```bash
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

## What Changed in Addon Configuration

### Before:
```hcl
{
  name    = "aws-ebs-csi-driver"
  version = "v1.55.0-eksbuild.1"  # Incompatible with EKS 1.35
}
```

### After:
```hcl
{
  name = "aws-ebs-csi-driver"
  # Version omitted - AWS auto-selects compatible version
}
```

## Benefits of This Approach

1. ✅ **Auto-compatibility**: AWS selects the correct version for your EKS version
2. ✅ **Less maintenance**: No need to manually track compatible versions
3. ✅ **Safer upgrades**: Reduces version mismatch errors
4. ✅ **Longer timeout**: 30 minutes instead of 20 for slow addons
5. ✅ **Conflict resolution**: Automatically handles addon conflicts

## Verify Addon Installation

After successful apply:

```bash
# Check addon status
aws eks describe-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 \
  --query 'addon.{Status:status,Version:addonVersion}'

# Check all addons
aws eks list-addons \
  --cluster-name testing-spectrio-test-eks-cluster \
  --region us-east-1

# Verify in Kubernetes
kubectl get pods -n kube-system | grep ebs-csi
```

## Future Addon Management

### Option 1: Let AWS Choose (Recommended)
```hcl
{
  name = "addon-name"
  # No version specified
}
```

### Option 2: Specify Exact Version
```hcl
{
  name    = "addon-name"
  version = "v1.x.x-eksbuild.x"
}
```

Use `check-addon-versions.sh` to find compatible versions before specifying.

## Troubleshooting

### If addon still fails:
1. Check node group status: `kubectl get nodes`
2. Check IAM permissions for EBS CSI driver
3. Review addon logs: `kubectl logs -n kube-system -l app=ebs-csi-controller`
4. Increase timeout further if needed (edit `modules/eks/main.tf`)

### If you need to force recreate:
```bash
terraform taint 'module.eks.aws_eks_addon.eks-addons["4"]'
terraform apply -var-file="dev.tfvars"
```
