#!/bin/bash -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=ap-southeast-1

echo ${AWS_ACCOUNT_ID}
echo ${AWS_REGION}

# shellcheck disable=SC2091
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build -t "clamav" -f ./Dockerfile .
docker tag "clamav" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/mmt/clamav_fargate:latest"
docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/mmt/clamav_fargate:latest"