# Tagging Fix Summary - terraform=true on ALL Resources

## Problem
EKS worker nodes (EC2 instances) and their derivatives (EBS volumes, ENIs) were not getting the `terraform = "true"` tag.

## Root Cause
Tags on `aws_eks_node_group` resource only apply to the node group resource itself, **NOT** to the EC2 instances it launches. AWS EKS manages the instance lifecycle, and tags need to be propagated via provider-level default tags.

## Solution Implemented

### 1. Provider-Level Default Tags (PRIMARY FIX)
Added `default_tags` block to AWS provider in `versions.tf`:

```hcl
provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      terraform = "true"
    }
  }
}
```

**Impact:** This applies `terraform = "true"` to **ALL** AWS resources created by Terraform, including:
- ✅ EC2 instances (worker nodes)
- ✅ EBS volumes (root and attached volumes)
- ✅ ENIs (Elastic Network Interfaces)
- ✅ VPC resources (VPC, subnets, IGW, NAT, route tables)
- ✅ Security groups
- ✅ EKS cluster
- ✅ IAM roles and policies
- ✅ Load balancers (created by Kubernetes)
- ✅ Any other AWS resource

### 2. Node Group Tags Cleanup
Simplified node group tags in `modules/eks/main.tf`:
- Removed redundant `tags_all` (deprecated pattern)
- Consolidated all tags into single `tags` block
- Fixed spot node group name typo (was showing "ondemand-nodes")

**Before:**
```hcl
tags = merge(var.common_tags, {
  "Name" = "${var.cluster_name}-ondemand-nodes"
})
tags_all = merge(var.common_tags, {
  "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  "Name" = "${var.cluster_name}-ondemand-nodes"
})
```

**After:**
```hcl
tags = merge(var.common_tags, {
  "Name" = "${var.cluster_name}-ondemand-nodes"
  "kubernetes.io/cluster/${var.cluster_name}" = "owned"
})
```

## Resources Now Tagged

### Automatically Tagged (via default_tags):
1. **EKS Worker Nodes** - EC2 instances
2. **EBS Volumes** - Root volumes and persistent volumes
3. **ENIs** - Network interfaces attached to instances
4. **VPC** - Virtual Private Cloud
5. **Subnets** - Public and private subnets
6. **Internet Gateway** - IGW
7. **NAT Gateway** - NAT GW
8. **Elastic IPs** - NAT EIP
9. **Route Tables** - Public and private route tables
10. **Security Groups** - EKS cluster and bastion SGs
11. **EKS Cluster** - The cluster itself
12. **EKS Node Groups** - On-demand and spot node groups
13. **IAM Roles** - All IAM roles
14. **IAM Policies** - All IAM policies
15. **Bastion Instance** - EC2 bastion host
16. **Load Balancers** - ALBs/NLBs created by Kubernetes

### Resources with Additional Tags:
All resources also get environment-specific tags via `common_tags`:
- `Name` - Resource-specific name
- `Env` - Environment (testing/staging/production)
- Any custom tags from tfvars

## Verification

### After Deployment:
```bash
# Run verification script
./verify-tags.sh testing-spectrio-test-eks-cluster us-east-1

# Or manually check worker nodes
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:kubernetes.io/cluster/testing-spectrio-test-eks-cluster,Values=owned" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`terraform`].Value]' \
  --output table

# Check EBS volumes
aws ec2 describe-volumes \
  --region us-east-1 \
  --filters "Name=tag:kubernetes.io/cluster/testing-spectrio-test-eks-cluster,Values=owned" \
  --query 'Volumes[*].[VolumeId,Tags[?Key==`terraform`].Value]' \
  --output table
```

## Important Notes

### 1. Default Tags Behavior
- Applied to **all** resources created after provider configuration
- Merged with resource-specific tags
- Cannot be overridden at resource level (by design)
- Inherited by child resources (e.g., EBS volumes from EC2 instances)

### 2. Existing Resources
If you have existing resources deployed **before** this fix:
- They will **NOT** automatically get the tag
- You need to either:
  - **Option A:** Destroy and recreate (recommended for dev)
  - **Option B:** Manually tag existing resources
  - **Option C:** Use `terraform apply` - Terraform will update tags in-place for most resources

### 3. Tag Propagation Timing
- Tags appear immediately on most resources
- EC2 instances launched by node groups: tags appear within 1-2 minutes
- EBS volumes: tags appear when volume is created/attached

### 4. Kubernetes-Created Resources
Resources created by Kubernetes controllers (e.g., LoadBalancers, EBS volumes via PVCs) will **also** get the `terraform = "true"` tag because:
- They're created using the node's IAM role
- The AWS provider's default tags apply to all API calls
- This is the expected behavior

### 5. Cost Allocation
The `terraform = "true"` tag can be used for:
- Cost allocation reports in AWS Cost Explorer
- Resource filtering and grouping
- Compliance and governance policies
- Automated cleanup scripts

## Files Modified

1. **versions.tf** - Added `default_tags` to AWS provider
2. **modules/eks/main.tf** - Cleaned up node group tags
3. **verify-tags.sh** - New verification script

## Testing Checklist

After applying changes:

- [ ] Run `./verify-tags.sh` to check all resources
- [ ] Verify EC2 instances have `terraform=true` tag
- [ ] Verify EBS volumes have `terraform=true` tag
- [ ] Verify ENIs have `terraform=true` tag
- [ ] Check AWS Cost Explorer can filter by `terraform` tag
- [ ] Verify new resources created by Kubernetes also get the tag

## Rollback

If issues occur, remove default_tags:

```hcl
provider "aws" {
  region = var.region
  # Remove default_tags block
}
```

Then run:
```bash
terraform apply -var-file="dev.tfvars"
```

Note: This will **remove** the `terraform=true` tag from resources on next apply.
