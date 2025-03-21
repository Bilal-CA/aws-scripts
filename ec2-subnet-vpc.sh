#!/bin/bash

# Output CSV file
OUTPUT_FILE="ec2_instances.csv"

# Specify the AWS region
REGION="us-east-1"

# Fetch EC2 instance details using AWS CLI for running instances
echo "Fetching running EC2 instance details for region: $REGION..."
INSTANCE_DATA=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId, Tags[?Key=='Name'].Value | [0] || 'N/A', PublicIpAddress || 'N/A', PrivateIpAddress || 'N/A', KeyName || 'N/A', Platform || 'Linux', SubnetId || 'N/A', VpcId || 'N/A']" \
    --output text)

# Fetch Subnet and VPC names
echo "Fetching subnet and VPC names..."
SUBNET_DATA=$(aws ec2 describe-subnets --region "$REGION" --query "Subnets[*].[SubnetId, Tags[?Key=='Name'].Value | [0] || 'N/A']" --output text)
VPC_DATA=$(aws ec2 describe-vpcs --region "$REGION" --query "Vpcs[*].[VpcId, Tags[?Key=='Name'].Value | [0] || 'N/A']" --output text)

# Create associative arrays for subnet and VPC names
declare -A SUBNET_NAMES
while IFS=$'\t' read -r subnet_id subnet_name; do
    SUBNET_NAMES[$subnet_id]=$subnet_name
done <<< "$SUBNET_DATA"

declare -A VPC_NAMES
while IFS=$'\t' read -r vpc_id vpc_name; do
    VPC_NAMES[$vpc_id]=$vpc_name
done <<< "$VPC_DATA"

# Write header to CSV file
echo "InstanceId,Name,PublicIp,PrivateIp,KeyName,Platform,SubnetId,SubnetName,VpcId,VpcName" > "$OUTPUT_FILE"

# Format and append instance data to CSV file
while IFS=$'\t' read -r instance_id name public_ip private_ip key_name platform subnet_id vpc_id; do
    subnet_name=${SUBNET_NAMES[$subnet_id]:-N/A}
    vpc_name=${VPC_NAMES[$vpc_id]:-N/A}
    echo "$instance_id,$name,$public_ip,$private_ip,$key_name,$platform,$subnet_id,$subnet_name,$vpc_id,$vpc_name" >> "$OUTPUT_FILE"
done <<< "$INSTANCE_DATA"

echo "EC2 instance details saved to $OUTPUT_FILE"
