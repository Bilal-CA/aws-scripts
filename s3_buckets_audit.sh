#!/bin/bash

# Output CSV file name
OUTPUT_FILE="s3_bucket_audit.csv"

# Write CSV header
echo "Bucket Name,Public Access,Encryption,Logging,Replication,Bucket Policy" > $OUTPUT_FILE

# Get the list of all S3 buckets
buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

# Loop through each bucket
for bucket in $buckets; do
    echo "Checking bucket: $bucket"

    # Check Public Access
    public_access=$(aws s3api get-public-access-block --bucket $bucket --query "PublicAccessBlockConfiguration" --output json 2>/dev/null)
    if [ -z "$public_access" ]; then
        public_access="Unknown"
    else
        is_public=$(echo "$public_access" | jq -r '[.BlockPublicAcls, .IgnorePublicAcls, .BlockPublicPolicy, .RestrictPublicBuckets] | index(false)')
        if [ "$is_public" == "null" ]; then
            public_access="Private"
        else
            public_access="Public"
        fi
    fi

    # Check Encryption
    encryption=$(aws s3api get-bucket-encryption --bucket $bucket --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" --output text 2>/dev/null)
    if [[ "$encryption" == "None" || -z "$encryption" ]]; then
        encryption="None"
    fi

    # Check Logging
    logging=$(aws s3api get-bucket-logging --bucket $bucket --query "LoggingEnabled.TargetBucket" --output text 2>/dev/null)
    if [ -z "$logging" ] || [ "$logging" == "None" ]; then
        logging="Disabled"
    else
        logging="Enabled"
    fi

    # Check Replication
    replication=$(aws s3api get-bucket-replication --bucket $bucket --query "ReplicationConfiguration.Rules" --output json 2>/dev/null)
    if [ -z "$replication" ]; then
        replication="None"
    else
        replication="Enabled"
    fi

    # Check Bucket Policy
    policy=$(aws s3api get-bucket-policy --bucket $bucket --query "Policy" --output text 2>/dev/null)
    if [ -z "$policy" ]; then
        bucket_policy="None"
    else
        # Extract the Principal from the policy
        principals=$(echo "$policy" | jq -r '.Statement[].Principal // empty' 2>/dev/null)

        if [ -z "$principals" ]; then
            bucket_policy="No Principals"
        else
            bucket_policy="Allowed Principals: $principals"
        fi
    fi

    # Append to CSV file
    echo "$bucket,$public_access,$encryption,$logging,$replication,$bucket_policy" >> $OUTPUT_FILE
done

echo "Audit complete. Results saved in $OUTPUT_FILE"
