#!/bin/bash
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Set default value for TARGET_REVISION
TARGET_REVISION="master"

# Ask for TARGET_REVISION
read -p "Please provide a target revision for the cluster resources chart (default is master): " user_target_revision
# If user input is not empty, use it; otherwise, keep the default
TARGET_REVISION=${user_target_revision:-$TARGET_REVISION}

# Ask for CLUSTER_NAME (no default value)
read -p "Enter the name of the cluster: " CLUSTER_NAME

# Check if CLUSTER_NAME is provided
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: CLUSTER_NAME cannot be empty."
    exit 1
fi

# Create a temporary file
temp_file=$(mktemp)

# Use sed to replace placeholders in the original file
sed -e "s|TARGET_REVISION|$TARGET_REVISION|g" \
    -e "s|CLUSTER_NAME|$CLUSTER_NAME|g" \
    $GEN3_HOME/kube/services/cluster-level-resources/app.yaml > "$temp_file"

echo "WARNING: Do you have a folder already set up for this environment in gen3-gitops, in the form of <cluster-name>/cluster-values/cluster-values.yaml? If not, this will not work."
echo ""
read -n 1 -s -r -p "Press any key to confirm and continue, or Ctrl+C to cancel..."
echo ""

# Apply the templated file with kubectl
kubectl apply -f "$temp_file"

# Clean up the temporary file
rm "$temp_file"

echo "Application has been applied to the cluster."