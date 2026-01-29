# Terraform Remote State Backend Setup

## Overview

This project uses a **single centralized backend** with workspace-based state isolation for managing multiple environments (dev, stage, prod).

## Architecture

### Backend Components

1. **S3 Bucket**: `spectrio-eks-terraform-state`
   - Stores Terraform state files
   - Versioning enabled (90-day retention for old versions)
   - Encryption at rest (AES256)
   - Public access blocked
   - TLS-only access enforced

2. **DynamoDB Table**: `spectrio-eks-terraform-locks`
   - Provides state locking mechanism
   - Prevents concurrent modifications
   - Point-in-time recovery enabled
   - Pay-per-request billing

### State File Organization

```
s3://spectrio-eks-terraform-state/
├── eks-cluster/terraform.tfstate                    # default workspace
└── env:/
    ├── dev/eks-cluster/terraform.tfstate           # dev workspace
    ├── stage/eks-cluster/terraform.tfstate         # stage workspace
    └── prod/eks-cluster/terraform.tfstate          # prod workspace
```

## Setup Instructions

### Prerequisites

- AWS CLI configured with appropriate credentials
- Permissions to create S3 buckets and DynamoDB tables
- Terraform installed

### Step 1: Create Backend Infrastructure

Run the setup script to create the S3 bucket and DynamoDB table:

```bash
./setup-backend.sh
```

This script will:
- Create S3 bucket with versioning and encryption
- Configure bucket policies for security
- Create DynamoDB table for state locking
- Enable point-in-time recovery

### Step 2: Initialize Terraform with Backend

If you have existing local state files, migrate them:

```bash
# Backup existing state files (if any)
mkdir -p backup
cp -r terraform.tfstate* backup/ 2>/dev/null || true

# Initialize with backend configuration
terraform init -migrate-state
```

If starting fresh:

```bash
terraform init
```

### Step 3: Verify Backend Configuration

```bash
# Check current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Verify state is stored remotely
aws s3 ls s3://spectrio-eks-terraform-state/eks-cluster/
```

## Working with Workspaces

### Create and Switch Workspaces

```bash
# Create workspaces (if not exists)
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

# Switch to desired workspace
terraform workspace select dev
```

### Apply Configuration per Environment

```bash
# Dev environment
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"

# Stage environment
terraform workspace select stage
terraform plan -var-file="stage.tfvars"
terraform apply -var-file="stage.tfvars"

# Prod environment
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Security Features

### S3 Bucket Security

- ✅ **Versioning**: Enabled with 90-day retention for old versions
- ✅ **Encryption**: AES256 server-side encryption
- ✅ **Public Access**: Completely blocked
- ✅ **TLS Enforcement**: HTTPS-only access via bucket policy
- ✅ **Lifecycle Policy**: Automatic cleanup of old versions

### DynamoDB Security

- ✅ **Point-in-Time Recovery**: Enabled for disaster recovery
- ✅ **Pay-per-Request**: Cost-effective billing model
- ✅ **Tagging**: Proper resource tagging for governance

### State Locking

State locking prevents:
- Concurrent modifications by multiple users
- Race conditions during apply operations
- State corruption from simultaneous writes

## Troubleshooting

### State Lock Issues

If you encounter a state lock error:

```bash
# View lock information
aws dynamodb get-item \
  --table-name spectrio-eks-terraform-locks \
  --key '{"LockID":{"S":"spectrio-eks-terraform-state/env:/dev/eks-cluster/terraform.tfstate-md5"}}'

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

### State File Recovery

To recover a previous state version:

```bash
# List versions
aws s3api list-object-versions \
  --bucket spectrio-eks-terraform-state \
  --prefix env:/dev/eks-cluster/terraform.tfstate

# Download specific version
aws s3api get-object \
  --bucket spectrio-eks-terraform-state \
  --key env:/dev/eks-cluster/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup
```

### Verify State Location

```bash
# Check where state is stored
terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="terraform_remote_state")'

# Or simply check the backend config
terraform init -backend-config="" 2>&1 | grep -A 5 "backend configuration"
```

## Best Practices

1. **Never commit state files**: Already in `.gitignore`
2. **Use workspace per environment**: Isolates state files
3. **Always use state locking**: Prevents concurrent modifications
4. **Regular backups**: S3 versioning provides automatic backups
5. **Least privilege access**: Restrict S3/DynamoDB access via IAM
6. **Monitor state changes**: Enable CloudTrail for audit logs

## Cost Considerations

### S3 Costs
- Storage: ~$0.023/GB/month (Standard tier)
- Requests: Minimal (only during terraform operations)
- Versioning: Old versions deleted after 90 days

### DynamoDB Costs
- Pay-per-request: ~$1.25 per million write requests
- Typical usage: <100 requests/month = negligible cost

**Estimated monthly cost**: < $1 USD

## Cleanup (Caution!)

To remove backend infrastructure (only if decommissioning project):

```bash
# Delete all state files from S3
aws s3 rm s3://spectrio-eks-terraform-state --recursive

# Delete S3 bucket
aws s3api delete-bucket --bucket spectrio-eks-terraform-state --region us-east-1

# Delete DynamoDB table
aws dynamodb delete-table --table-name spectrio-eks-terraform-locks --region us-east-1
```

⚠️ **Warning**: This will permanently delete all state files. Ensure all infrastructure is destroyed first!

## Support

For issues or questions:
1. Check Terraform backend documentation: https://www.terraform.io/docs/language/settings/backends/s3.html
2. Review AWS S3/DynamoDB documentation
3. Contact DevOps team
