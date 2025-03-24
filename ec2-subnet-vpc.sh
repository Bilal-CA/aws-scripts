#!/bin/bash

# Output CSV file
OUTPUT_FILE="ec2_instances.csv"

# List of AWS regions
REGIONS=("us-east-1" "us-west-1")

# Write header to CSV file
echo "InstanceId,Name,PublicIp,PrivateIp,KeyName,Platform,Region,SubnetId,VpcId" > "$OUTPUT_FILE"

# Loop through each region
for REGION in "${REGIONS[@]}"; do
    echo "Fetching running EC2 instance details for region: $REGION..."

    # Fetch Running EC2 instance details
    INSTANCE_DATA=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].[InstanceId, Tags[?Key=='Name'].Value | [0] || 'N/A', PublicIpAddress || 'N/A', PrivateIpAddress || 'N/A', KeyName || 'N/A', Platform || 'Linux', SubnetId || 'N/A', VpcId || 'N/A']" \
        --output text)

    # Process and append data
    while IFS=$'\t' read -r instance_id name public_ip private_ip key_name platform subnet_id vpc_id; do
        echo "$instance_id,$name,$public_ip,$private_ip,$key_name,$platform,$REGION,$subnet_id,$vpc_id" >> "$OUTPUT_FILE"
    done <<< "$INSTANCE_DATA"
done

echo "EC2 details saved to $OUTPUT_FILE"
