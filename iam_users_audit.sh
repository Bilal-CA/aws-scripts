#!/bin/bash

# Define output file
OUTPUT_FILE="iam_users_info.csv"

# Create the CSV header
echo "Username,LastAccessDate,UnusedAccessKeys,AccessKeyAges,AccessKeyLastUsed,RoleNames" > $OUTPUT_FILE

# Get the list of all IAM users
USER_LIST=$(aws iam list-users --query 'Users[*].UserName' --output text)

# Loop through each user
for USER in $USER_LIST
do
  # Get the last access date for the user
  LAST_ACCESS_DATE=$(aws iam get-user --user-name $USER --query 'User.PasswordLastUsed' --output text)
  
  # If the user has never logged in
  if [ "$LAST_ACCESS_DATE" == "None" ]; then
    LAST_ACCESS_DATE="Never"
  fi
  
  # Get the list of access keys
  KEYS=$(aws iam list-access-keys --user-name $USER --query 'AccessKeyMetadata[*].{ID:AccessKeyId,Status:Status,CreateDate:CreateDate}' --output json)

  UNUSED_KEYS=""
  ACCESS_KEY_AGES=""
  ACCESS_KEY_LAST_USED=""

  for key in $(echo "$KEYS" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${key} | base64 --decode | jq -r ${1}
    }
    KEY_ID=$(_jq '.ID')
    STATUS=$(_jq '.Status')
    CREATE_DATE=$(_jq '.CreateDate')
    
    # Calculate the access key age in days
    if [ "$CREATE_DATE" != "null" ]; then
      CREATE_DATE_TIMESTAMP=$(date -d "$CREATE_DATE" +%s)
      CURRENT_TIMESTAMP=$(date +%s)
      AGE=$(( (CURRENT_TIMESTAMP - CREATE_DATE_TIMESTAMP) / 86400 ))  # Convert seconds to days
    else
      AGE="N/A"
    fi
    
    # Get the last used date of the access key (only one extra AWS CLI call per key)
    LAST_USED_DATE=$(aws iam get-access-key-last-used --access-key-id "$KEY_ID" --query 'AccessKeyLastUsed.LastUsedDate' --output text)

    # If last used date is null
    if [ "$LAST_USED_DATE" == "None" ]; then
      LAST_USED_DATE="Never"
    fi

    # If the key is inactive or never used
    if [[ "$STATUS" == "Inactive" || "$LAST_USED_DATE" == "Never" ]]; then
      UNUSED_KEYS="$UNUSED_KEYS$KEY_ID (Last used: $LAST_USED_DATE), "
    fi
    
    # Access key details
    ACCESS_KEY_AGES="$ACCESS_KEY_AGES$KEY_ID (Age: $AGE days), "
    ACCESS_KEY_LAST_USED="$ACCESS_KEY_LAST_USED$KEY_ID (Last used: $LAST_USED_DATE), "
  done
  
  # Format output fields
  UNUSED_KEYS=$(echo "$UNUSED_KEYS" | sed 's/, $//')
  ACCESS_KEY_AGES=$(echo "$ACCESS_KEY_AGES" | sed 's/, $//')
  ACCESS_KEY_LAST_USED=$(echo "$ACCESS_KEY_LAST_USED" | sed 's/, $//')
  
  # Get the associated roles for the user
  ROLE_NAMES=$(aws iam list-groups-for-user --user-name $USER --query 'Groups[*].GroupName' --output text)
  
  # Append user information
  echo "$USER,$LAST_ACCESS_DATE,$UNUSED_KEYS,$ACCESS_KEY_AGES,$ACCESS_KEY_LAST_USED,$ROLE_NAMES" >> $OUTPUT_FILE
done

echo "User information has been saved to $OUTPUT_FILE"
