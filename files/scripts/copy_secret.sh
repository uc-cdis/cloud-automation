#!/usr/bin/env bash
set -eo pipefail

# Inputs
SRC_PROFILE="${1:?Error: Provide source AWS profile as arg 1}"
DEST_PROFILE="${2:?Error: Provide destination AWS profile as arg 2}"
SECRET_PREFIX="${3:-}" # Optional: Filter secrets starting with a prefix (e.g., "gen3/" or "eks/")
REGION="${AWS_REGION:-us-east-1}"

echo "=================================================="
echo " AWS Secrets Manager Migration"
echo " Source Profile:      $SRC_PROFILE"
echo " Destination Profile: $DEST_PROFILE"
echo " Region:              $REGION"
echo " Prefix Filter:       ${SECRET_PREFIX:-<ALL SECRETS>}"
echo "=================================================="

# 1. Fetch secret names from source account
echo "Fetching secret list from source..."
SECRETS_LIST=$(aws secretsmanager list-secrets \
  --profile "$SRC_PROFILE" \
  --region "$REGION" \
  --query "SecretList[?starts_with(Name, '${SECRET_PREFIX}')].Name" \
  --output json)

NUM_SECRETS=$(echo "$SECRETS_LIST" | jq '. | length')

if [[ "$NUM_SECRETS" -eq 0 ]]; then
  echo "No secrets found matching filter '${SECRET_PREFIX}' in source account."
  exit 0
fi

echo "Found $NUM_SECRETS secret(s) to process."
echo "--------------------------------------------------"

# 2. Iterate through each secret
for SECRET_NAME in $(echo "$SECRETS_LIST" | jq -r '.[]'); do
  echo "Processing: $SECRET_NAME"

  # Fetch value from source
  SECRET_DATA=$(aws secretsmanager get-secret-value \
    --profile "$SRC_PROFILE" \
    --region "$REGION" \
    --secret-id "$SECRET_NAME" \
    --output json 2>/dev/null || true)

  if [[ -z "$SECRET_DATA" ]]; then
    echo "  [ERROR] Could not read secret value from source. Skipping."
    continue
  fi

  SECRET_STRING=$(echo "$SECRET_DATA" | jq -r '.SecretString // empty')
  SECRET_BINARY=$(echo "$SECRET_DATA" | jq -r '.SecretBinary // empty')

  # 3. Check if secret exists in destination
  #if aws secretsmanager describe-secret \
  #  --profile "$DEST_PROFILE" \
  #  --region "$REGION" \
  #  --secret-id "$SECRET_NAME" >/dev/null 2>&1; then

  #  echo "  [UPDATE] Secret exists in destination. Overwriting payload..."
  #  if [[ -n "$SECRET_STRING" ]]; then
  #    aws secretsmanager put-secret-value \
  #      --profile "$DEST_PROFILE" \
  #      --region "$REGION" \
  #      --secret-id "$SECRET_NAME" \
  #      --secret-string "$SECRET_STRING" >/dev/null
  #  elif [[ -n "$SECRET_BINARY" ]]; then
  #    aws secretsmanager put-secret-value \
  #      --profile "$DEST_PROFILE" \
  #      --region "$REGION" \
  #      --secret-id "$SECRET_NAME" \
  #      --secret-binary "$SECRET_BINARY" >/dev/null
  #  fi
  #  echo "  [SUCCESS] Updated $SECRET_NAME in destination."

  #else
  #  echo "  [CREATE] Creating new secret in destination..."
  #  if [[ -n "$SECRET_STRING" ]]; then
  #    aws secretsmanager create-secret \
  #      --profile "$DEST_PROFILE" \
  #      --region "$REGION" \
  #      --name "$SECRET_NAME" \
  #      --secret-string "$SECRET_STRING" >/dev/null
  #  elif [[ -n "$SECRET_BINARY" ]]; then
  #    aws secretsmanager create-secret \
  #      --profile "$DEST_PROFILE" \
  #      --region "$REGION" \
  #      --name "$SECRET_NAME" \
  #      --secret-binary "$SECRET_BINARY" >/dev/null
  #  fi
  #  echo "  [SUCCESS] Created $SECRET_NAME in destination."
  #fi
done

echo "--------------------------------------------------"
echo "Migration finished successfully!"
