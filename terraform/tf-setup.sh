#!/bin/bash

AWS_REGION=ap-southeast-1

# Create S3 Bucket
MY_ARN=$(aws iam get-user --query User.Arn --output text 2>/dev/null)
aws s3 mb "s3://mm-tf-clamav-fargate-state" --region ${AWS_REGION}
sed -e "s/RESOURCE/arn:aws:s3:::mm-tf-clamav-fargate-state/g" -e "s/KEY/terraform.tfstate/g" -e "s|ARN|${MY_ARN}|g" "$(dirname "$0")/templates/s3_policy.json" > new-policy.json
aws s3api put-bucket-policy --bucket "mm-tf-clamav-fargate-state" --policy file://new-policy.json
aws s3api put-public-access-block --bucket "mm-tf-clamav-fargate-state" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-encryption --bucket "mm-tf-clamav-fargate-state" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
rm new-policy.json

# Create DynamoDB Table
aws dynamodb create-table \
  --table-name "tf-dynamodb-lock" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region ${AWS_REGION}