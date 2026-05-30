#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-tagify}"
AWS_REGION="${AWS_REGION:-us-east-1}"
VPC_ID="${VPC_ID:-}"
SUBNET_ID="${SUBNET_ID:-}"
KEY_NAME="${KEY_NAME:-}"
AMI_ID="${AMI_ID:-}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
SSH_CIDR="${SSH_CIDR:-0.0.0.0/0}"
HTTP_CIDR="${HTTP_CIDR:-0.0.0.0/0}"
CREATE_ECR="${CREATE_ECR:-true}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_FILE="${ROOT_DIR}/aws/ec2-ecr-cloudwatch-policy.json"

require_value() {
  local name="$1"
  local value="${!name:-}"

  if [ -z "$value" ]; then
    echo "${name} is required."
    exit 1
  fi
}

aws_cli() {
  aws --region "$AWS_REGION" "$@"
}

ensure_ecr_repository() {
  if [ "$CREATE_ECR" != "true" ]; then
    return
  fi

  if aws_cli ecr describe-repositories --repository-names "$APP_NAME" >/dev/null 2>&1; then
    echo "ECR repository already exists: ${APP_NAME}"
    return
  fi

  aws_cli ecr create-repository \
    --repository-name "$APP_NAME" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 >/dev/null

  echo "Created ECR repository: ${APP_NAME}"
}

ensure_iam_role() {
  local role_name="${APP_NAME}-ec2-role"
  local profile_name="${APP_NAME}-ec2-profile"
  local policy_name="${APP_NAME}-ec2-ecr-cloudwatch"

  if ! aws_cli iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    aws_cli iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": { "Service": "ec2.amazonaws.com" },
            "Action": "sts:AssumeRole"
          }
        ]
      }' >/dev/null
  fi

  aws_cli iam put-role-policy \
    --role-name "$role_name" \
    --policy-name "$policy_name" \
    --policy-document "file://${POLICY_FILE}" >/dev/null

  if ! aws_cli iam get-instance-profile --instance-profile-name "$profile_name" >/dev/null 2>&1; then
    aws_cli iam create-instance-profile --instance-profile-name "$profile_name" >/dev/null
  fi

  if ! aws_cli iam get-instance-profile --instance-profile-name "$profile_name" \
    --query "InstanceProfile.Roles[?RoleName=='${role_name}'].RoleName" \
    --output text | grep -q "$role_name"; then
    aws_cli iam add-role-to-instance-profile \
      --instance-profile-name "$profile_name" \
      --role-name "$role_name" >/dev/null
    echo "Waiting for IAM instance profile propagation..."
    sleep 10
  fi

  echo "$profile_name"
}

ensure_security_group() {
  local group_name="${APP_NAME}-ec2-sg"
  local group_id

  group_id="$(aws_cli ec2 describe-security-groups \
    --filters "Name=group-name,Values=${group_name}" "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[0].GroupId" \
    --output text)"

  if [ "$group_id" = "None" ]; then
    group_id="$(aws_cli ec2 create-security-group \
      --group-name "$group_name" \
      --description "Allow SSH and HTTP access for ${APP_NAME}" \
      --vpc-id "$VPC_ID" \
      --query "GroupId" \
      --output text)"
  fi

  aws_cli ec2 authorize-security-group-ingress \
    --group-id "$group_id" \
    --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${SSH_CIDR},Description='SSH'}]" >/dev/null 2>&1 || true

  aws_cli ec2 authorize-security-group-ingress \
    --group-id "$group_id" \
    --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=${HTTP_CIDR},Description='HTTP'}]" >/dev/null 2>&1 || true

  echo "$group_id"
}

latest_amazon_linux_ami() {
  aws_cli ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query "Parameter.Value" \
    --output text
}

launch_instance() {
  local instance_profile="$1"
  local security_group_id="$2"
  local ami_id="$AMI_ID"

  if [ -z "$ami_id" ]; then
    ami_id="$(latest_amazon_linux_ami)"
  fi

  aws_cli ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$security_group_id" \
    --iam-instance-profile "Name=${instance_profile}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${APP_NAME}-api},{Key=Project,Value=${APP_NAME}}]" \
    --query "Instances[0].{InstanceId:InstanceId,PublicIpAddress:PublicIpAddress,State:State.Name}" \
    --output table
}

require_value VPC_ID
require_value SUBNET_ID
require_value KEY_NAME

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required."
  exit 1
fi

ensure_ecr_repository
INSTANCE_PROFILE="$(ensure_iam_role)"
SECURITY_GROUP_ID="$(ensure_security_group)"

echo "Launching ${APP_NAME} EC2 instance..."
launch_instance "$INSTANCE_PROFILE" "$SECURITY_GROUP_ID"

cat <<EOF

Next:
1. Wait for the instance to pass status checks.
2. SSH into it and run:
   sudo APP_USER=ec2-user bash scripts/setup-ec2.sh
3. Add the instance public DNS/IP as GitHub secret EC2_HOST.
EOF
