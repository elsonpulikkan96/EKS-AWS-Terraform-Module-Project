#!/bin/bash
# Create SSH key pairs for each environment

ENVIRONMENTS=("dev" "stage" "prod")
REGION="us-east-1"

for ENV in "${ENVIRONMENTS[@]}"; do
    KEY_NAME="my-${ENV}-key"
    KEY_FILE="${KEY_NAME}.pem"
    
    echo "Creating key pair: ${KEY_NAME}"
    
    # Create key pair and save private key
    aws ec2 create-key-pair \
        --key-name "${KEY_NAME}" \
        --region "${REGION}" \
        --query 'KeyMaterial' \
        --output text > "${KEY_FILE}"
    
    # Set proper permissions
    chmod 400 "${KEY_FILE}"
    
    echo "✓ Key pair created: ${KEY_FILE}"
done

echo ""
echo "All key pairs created successfully!"
echo "Keep these .pem files secure and do not commit to git."
