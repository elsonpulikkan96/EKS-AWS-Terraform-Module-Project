# Launch Template MIME Format Issue - RESOLVED

## Problem

```
Error: waiting for EKS Node Group create: unexpected state 'CREATE_FAILED'
last error: Ec2LaunchTemplateInvalidConfiguration: User data was not in the MIME multipart format.
```

## Root Cause Analysis

### Why This Error Occurs

When using a **launch template with EKS node groups**, AWS EKS has specific requirements:

1. **EKS automatically handles node bootstrapping** - It runs `/etc/eks/bootstrap.sh` to join nodes to the cluster
2. **Custom user data must be in MIME multipart format** - If you provide user data, it must be properly formatted to merge with EKS's bootstrap process
3. **Plain bash scripts cause conflicts** - Simple bash scripts don't meet the MIME multipart requirement

### The Misconception

We initially thought we needed to:
- Install SSM agent via user data
- Manually run the EKS bootstrap script

**This was WRONG!**

### The Reality

**FACT: SSM Agent is PRE-INSTALLED in EKS Optimized AMI since 2020**

- Amazon Linux 2 EKS Optimized AMI includes SSM agent by default
- EKS automatically bootstraps nodes when using node groups
- Custom user data is NOT needed for basic functionality

## The Solution

### What We Changed

**REMOVED** all custom user data from launch templates:

#### Before (WRONG):
```hcl
resource "aws_launch_template" "ondemand" {
  name_prefix = "${var.cluster_name}-ondemand-"
  key_name    = var.node_key_name
  user_data   = base64encode(templatefile("${path.module}/ssm-userdata.sh", {
    CLUSTER_NAME = var.cluster_name
  }))
  # ... rest of config
}
```

#### After (CORRECT):
```hcl
resource "aws_launch_template" "ondemand" {
  name_prefix = "${var.cluster_name}-ondemand-"
  key_name    = var.node_key_name
  
  # Note: SSM Agent is pre-installed in EKS Optimized AMI
  # No custom user_data needed - EKS handles bootstrap automatically
  
  # ... rest of config
}
```

### Files Modified

1. **modules/eks/main.tf**
   - Removed `user_data` from `aws_launch_template.ondemand`
   - Removed `user_data` from `aws_launch_template.spot`
   - Added comments explaining why

2. **README.md**
   - Updated SSM section to clarify SSM agent is pre-installed
   - Removed references to custom userdata script

3. **modules/eks/ssm-userdata.sh**
   - File kept for reference but no longer used
   - Can be deleted if desired

## Why This Works

### SSM Access Still Works Because:

1. **SSM Agent Pre-installed**: EKS Optimized AMI includes it
2. **IAM Policy Attached**: `AmazonSSMManagedInstanceCore` policy on node role
3. **No Custom Installation Needed**: Agent starts automatically

### EKS Bootstrap Still Works Because:

1. **EKS Node Groups Handle It**: When using `aws_eks_node_group` resource
2. **Automatic Process**: EKS service manages the bootstrap
3. **No Manual Intervention**: Works out of the box

## When You WOULD Need Custom User Data

You only need custom user data in MIME multipart format if:

1. Installing additional software (not SSM agent)
2. Custom configurations beyond EKS defaults
3. Running custom startup scripts

### Example: Proper MIME Multipart Format (If Needed)

```bash
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
# Your custom script here
yum install -y custom-package

--==MYBOUNDARY==--
```

**But we don't need this for SSM access!**

## Verification

After applying the fix:

```bash
# 1. Apply the changes
terraform workspace select stage
terraform apply -var-file="stage.tfvars"

# 2. Wait for nodes to be ready
kubectl get nodes

# 3. Verify SSM access
aws ssm describe-instance-information --region us-east-1

# 4. Test SSM connection
NODE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/staging-spectrio-stage-eks-cluster,Values=owned" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-east-1)

aws ssm start-session --target $NODE_ID --region us-east-1

# 5. Once connected, verify SSM agent
sudo systemctl status amazon-ssm-agent
```

## Key Takeaways

### ✅ DO:
- Use launch templates for SSH keys, tags, and EBS volumes
- Rely on EKS Optimized AMI defaults
- Attach IAM policies for SSM access
- Let EKS handle node bootstrapping

### ❌ DON'T:
- Add custom user data unless absolutely necessary
- Try to manually install SSM agent (it's already there)
- Manually run EKS bootstrap script (EKS does it)
- Use plain bash scripts in launch template user data

## Summary

**The fix is simple: REMOVE custom user data from launch templates.**

- SSM agent is already in the AMI
- EKS handles bootstrap automatically
- IAM policy provides SSM access
- Everything works without custom user data

**This is the correct, production-ready approach.**
