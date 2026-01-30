#!/bin/bash

# Terraform Backend Setup Script
# This script creates the S3 bucket and DynamoDB table for Terraform remote state

set -e

# Configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET_NAME="eks-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="eks-terraform-locks-${AWS_ACCOUNT_ID}"

echo "=========================================="
echo "Terraform Backend Setup"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Region: ${REGION}"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "=========================================="
echo ""

# Check if bucket exists
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "✓ S3 bucket '${BUCKET_NAME}' already exists"
else
    echo "Creating S3 bucket '${BUCKET_NAME}'..."
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}"
    
    echo "✓ S3 bucket created"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling default encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✓ Public access blocked"

# Add bucket policy for secure access
echo "Adding bucket policy..."
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EnforcedTLS",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket "${BUCKET_NAME}" \
    --policy file:///tmp/bucket-policy.json

rm /tmp/bucket-policy.json
echo "✓ Bucket policy applied"

# Add lifecycle policy for old versions
echo "Adding lifecycle policy for state file versions..."
cat > /tmp/lifecycle-policy.json <<'EOF'
{
    "Rules": [
        {
            "ID": "DeleteOldVersions",
            "Filter": {
                "Prefix": ""
            },
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET_NAME}" \
    --lifecycle-configuration file:///tmp/lifecycle-policy.json

rm /tmp/lifecycle-policy.json
echo "✓ Lifecycle policy applied"

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" 2>/dev/null; then
    echo "✓ DynamoDB table '${DYNAMODB_TABLE}' already exists"
else
    echo "Creating DynamoDB table '${DYNAMODB_TABLE}'..."
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}" \
        --tags Key=Project,Value=eks-terraform Key=ManagedBy,Value=terraform Key=Purpose,Value=state-locking
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
    echo "✓ DynamoDB table created"
fi

# Enable point-in-time recovery
echo "Enabling point-in-time recovery on DynamoDB table..."
aws dynamodb update-continuous-backups \
    --table-name "${DYNAMODB_TABLE}" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "${REGION}"

echo "✓ Point-in-time recovery enabled"

# Generate backend configuration file
echo "Generating backend configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat > "${SCRIPT_DIR}/backend.hcl" <<EOF
bucket         = "${BUCKET_NAME}"
region         = "${REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
EOF

echo "✓ Backend configuration file created: ${SCRIPT_DIR}/backend.hcl"

echo ""
echo "=========================================="
echo "✓ Backend setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Run: terraform init -backend-config=backend.hcl"
echo "2. Verify state migration"
echo ""
echo "Backend details:"
echo "  - Bucket: ${BUCKET_NAME}"
echo "  - DynamoDB: ${DYNAMODB_TABLE}"
echo "  - Region: ${REGION}"
echo ""
