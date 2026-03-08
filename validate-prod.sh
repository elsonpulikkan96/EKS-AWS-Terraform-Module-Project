#!/bin/bash
# Production Deployment Validation Script
# Run this before deploying to production

set -e

echo "=========================================="
echo "Production Deployment Pre-Flight Checks"
echo "=========================================="
echo ""

ERRORS=0

# Check 1: Validate prod.tfvars exists
if [ ! -f "prod.tfvars" ]; then
    echo "❌ ERROR: prod.tfvars not found"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ prod.tfvars found"
fi

# Check 2: Validate public_access_cidrs is not 0.0.0.0/0
if grep -q 'public_access_cidrs.*=.*\["0.0.0.0/0"\]' prod.tfvars 2>/dev/null; then
    echo "❌ ERROR: Production uses 0.0.0.0/0 for public_access_cidrs"
    echo "   Update prod.tfvars with your organization's IP ranges"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ public_access_cidrs properly restricted"
fi

# Check 3: Validate public_access_cidrs is not placeholder
if grep -q 'YOUR_IP_HERE' prod.tfvars 2>/dev/null; then
    echo "❌ ERROR: public_access_cidrs contains placeholder 'YOUR_IP_HERE'"
    echo "   Replace with actual IP address or CIDR block"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ No placeholder values in public_access_cidrs"
fi

# Check 4: Validate backend.hcl exists
if [ ! -f "backend.hcl" ]; then
    echo "⚠️  WARNING: backend.hcl not found. Run ./setup-backend.sh first"
else
    echo "✓ backend.hcl exists"
fi

# Check 5: Validate AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ ERROR: AWS credentials not configured or invalid"
    ERRORS=$((ERRORS + 1))
else
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✓ AWS credentials valid (Account: $ACCOUNT_ID)"
fi

# Check 6: Validate Terraform version
if ! command -v terraform &>/dev/null; then
    echo "❌ ERROR: Terraform not installed"
    ERRORS=$((ERRORS + 1))
else
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
    echo "✓ Terraform installed (version: $TF_VERSION)"
fi

# Check 7: Validate kubectl installed
if ! command -v kubectl &>/dev/null; then
    echo "⚠️  WARNING: kubectl not installed"
else
    echo "✓ kubectl installed"
fi

# Check 8: Check for state locks
if [ -f "backend.hcl" ]; then
    BUCKET=$(grep 'bucket' backend.hcl | awk -F'"' '{print $2}')
    TABLE=$(grep 'dynamodb_table' backend.hcl | awk -F'"' '{print $2}')
    
    if [ -n "$TABLE" ]; then
        LOCK_COUNT=$(aws dynamodb scan --table-name "$TABLE" --select COUNT --query 'Count' --output text 2>/dev/null || echo "0")
        if [ "$LOCK_COUNT" -gt 0 ]; then
            echo "⚠️  WARNING: $LOCK_COUNT state lock(s) found in DynamoDB"
            echo "   Ensure no other Terraform operations are running"
        else
            echo "✓ No active state locks"
        fi
    fi
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All critical checks passed"
    echo "=========================================="
    echo ""
    echo "Ready to deploy production environment"
    echo ""
    echo "Next steps:"
    echo "  1. Review prod.tfvars one more time"
    echo "  2. Run: terraform workspace select prod"
    echo "  3. Run: terraform plan -var-file=prod.tfvars"
    echo "  4. Review the plan carefully"
    echo "  5. Run: terraform apply -var-file=prod.tfvars"
    exit 0
else
    echo "❌ $ERRORS critical error(s) found"
    echo "=========================================="
    echo ""
    echo "Fix the errors above before deploying to production"
    exit 1
fi
