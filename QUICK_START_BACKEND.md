# Quick Start Guide - Remote State Backend

## First Time Setup (Run Once)

```bash
# 1. Setup backend infrastructure
./setup-backend.sh

# 2. Initialize Terraform with backend
terraform init -migrate-state

# 3. Create workspaces
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
```

## Daily Workflow

### Dev Environment
```bash
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### Stage Environment
```bash
terraform workspace select stage
terraform plan -var-file="stage.tfvars"
terraform apply -var-file="stage.tfvars"
```

### Prod Environment
```bash
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Verify Backend

```bash
# Check current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Verify remote state
aws s3 ls s3://spectrio-eks-terraform-state/eks-cluster/ --recursive
```

## Troubleshooting

### State Lock Error
```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

### Re-initialize Backend
```bash
terraform init -reconfigure
```

### Check State Location
```bash
terraform state list
```

## Important Notes

✅ State files are stored in S3 (not locally)
✅ Each workspace has isolated state
✅ State locking prevents concurrent modifications
✅ Versioning enabled (90-day retention)
✅ Encryption at rest enabled

❌ Never manually edit state files
❌ Never commit state files to git
❌ Never force-unlock without coordination

For detailed documentation, see [BACKEND_SETUP.md](BACKEND_SETUP.md)
