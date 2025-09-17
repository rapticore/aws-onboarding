#!/bin/bash

# Lambda Cross-Region Duplication Script with Local Caching
# Usage: ./duplicate-lambda.sh <source_function_arn> <target_region> [--force-refresh]

set -e

# Check for required tools
check_dependencies() {
    local missing_tools=()

    if ! command -v aws >/dev/null 2>&1; then
        missing_tools+=("aws-cli")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi

    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Install missing tools:"
        echo "  Ubuntu/Debian: sudo apt-get install ${missing_tools[*]}"
        echo "  macOS: brew install ${missing_tools[*]}"
        echo "  RHEL/CentOS: sudo yum install ${missing_tools[*]}"
        exit 1
    fi
}

# Check dependencies first
check_dependencies

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/lambda-backup"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Parse arguments
FORCE_REFRESH=false
ARGS=()

for arg in "$@"; do
    case $arg in
        --force-refresh)
            FORCE_REFRESH=true
            shift
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Validate arguments
if [ ${#ARGS[@]} -ne 2 ]; then
    echo "Usage: $0 <source_function_arn> <target_region> [--force-refresh]"
    echo "Example: $0 arn:aws:lambda:us-west-2:123456789012:function:my-function ap-southeast-2"
    echo "Options:"
    echo "  --force-refresh    Download fresh copy from AWS (ignore cache)"
    exit 1
fi

SOURCE_ARN="${ARGS[0]}"
TARGET_REGION="${ARGS[1]}"

# Extract components from ARN
# ARN format: arn:aws:lambda:region:account:function:function-name
IFS=':' read -ra ARN_PARTS <<< "$SOURCE_ARN"

if [ ${#ARN_PARTS[@]} -lt 6 ] || [ "${ARN_PARTS[0]}" != "arn" ] || [ "${ARN_PARTS[2]}" != "lambda" ] || [ "${ARN_PARTS[5]}" != "function" ]; then
    echo "Error: Invalid Lambda function ARN format"
    echo "Expected: arn:aws:lambda:region:account:function:function-name"
    exit 1
fi

SOURCE_REGION="${ARN_PARTS[3]}"
ACCOUNT_ID="${ARN_PARTS[4]}"
# Function name is everything after "function:" - handle names with hyphens/colons
FUNCTION_NAME="${SOURCE_ARN#*:function:}"

echo "Source Region: $SOURCE_REGION"
echo "Target Region: $TARGET_REGION"
echo "Function Name: $FUNCTION_NAME"
echo "Account ID: $ACCOUNT_ID"
echo "Backup Directory: $BACKUP_DIR"
echo ""

# File paths
FUNCTION_ZIP="$BACKUP_DIR/function.zip"
FUNCTION_CONFIG="$BACKUP_DIR/function-config.json"
METADATA_FILE="$BACKUP_DIR/metadata.json"

# Check if cached files exist and are valid
USE_CACHE=false
if [ "$FORCE_REFRESH" = false ] && [ -f "$FUNCTION_ZIP" ] && [ -f "$FUNCTION_CONFIG" ] && [ -f "$METADATA_FILE" ]; then
    echo "Found cached Lambda files:"

    # Display cache info
    if [ -f "$METADATA_FILE" ]; then
        echo "Cache created: $(jq -r '.backup_date' "$METADATA_FILE" 2>/dev/null || echo "unknown")"
        echo "Source ARN: $(jq -r '.source_arn' "$METADATA_FILE" 2>/dev/null || echo "unknown")"
        echo "Source Region: $(jq -r '.source_region' "$METADATA_FILE" 2>/dev/null || echo "unknown")"
    fi

    read -p "Use cached files? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Will download fresh copy from AWS..."
    else
        USE_CACHE=true
        echo "Using cached files..."
    fi
fi

if [ "$USE_CACHE" = false ]; then
    echo "Downloading from AWS..."

    # Step 1: Get function configuration
    echo "1. Fetching function configuration..."
    aws lambda get-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --region "$SOURCE_REGION" \
        > "$FUNCTION_CONFIG"

    # Step 2: Download function code
    echo "2. Downloading function code..."
    CODE_LOCATION=$(aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$SOURCE_REGION" \
        --query 'Code.Location' \
        --output text)

    curl -s "$CODE_LOCATION" -o "$FUNCTION_ZIP"

    # Step 3: Create metadata file
    echo "3. Creating metadata..."
    cat > "$METADATA_FILE" << EOF
{
    "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "source_arn": "$SOURCE_ARN",
    "source_region": "$SOURCE_REGION",
    "function_name": "$FUNCTION_NAME",
    "account_id": "$ACCOUNT_ID"
}
EOF

    echo "Files cached successfully in $BACKUP_DIR"
else
    echo "Using cached Lambda files..."
fi

echo "4. Extracting configuration values..."
RUNTIME=$(jq -r '.Runtime' "$FUNCTION_CONFIG")
HANDLER=$(jq -r '.Handler' "$FUNCTION_CONFIG")
ROLE_ARN=$(jq -r '.Role' "$FUNCTION_CONFIG")
DESCRIPTION=$(jq -r '.Description // "Duplicated from ${SOURCE_REGION}"' "$FUNCTION_CONFIG")
TIMEOUT=$(jq -r '.Timeout' "$FUNCTION_CONFIG")
MEMORY_SIZE=$(jq -r '.MemorySize' "$FUNCTION_CONFIG")

# Extract environment variables if they exist
ENV_VARS=$(jq -r '.Environment.Variables // {}' "$FUNCTION_CONFIG")

echo "Runtime: $RUNTIME"
echo "Handler: $HANDLER"
echo "Role: $ROLE_ARN"
echo ""

# Step 5: Check if function already exists in target region
echo "5. Checking if function exists in target region..."
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$TARGET_REGION" >/dev/null 2>&1; then
    echo "Warning: Function '$FUNCTION_NAME' already exists in $TARGET_REGION"
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        UPDATE_MODE=true
    else
        echo "Aborted."
        exit 1
    fi
else
    UPDATE_MODE=false
fi

# Step 6: Create or update function
if [ "$UPDATE_MODE" = true ]; then
    echo "6. Updating existing function..."

    # Update function code
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$FUNCTION_ZIP" \
        --region "$TARGET_REGION"

    # Update function configuration
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --handler "$HANDLER" \
        --description "$DESCRIPTION" \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY_SIZE" \
        --environment "Variables=$ENV_VARS" \
        --region "$TARGET_REGION"
else
    echo "6. Creating new function..."

    # Build create-function command
    CREATE_CMD="aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --role $ROLE_ARN \
        --handler $HANDLER \
        --zip-file fileb://$FUNCTION_ZIP \
        --description \"$DESCRIPTION\" \
        --timeout $TIMEOUT \
        --memory-size $MEMORY_SIZE \
        --region $TARGET_REGION"

    # Add environment variables if they exist
    if [ "$ENV_VARS" != "{}" ] && [ "$ENV_VARS" != "null" ]; then
        CREATE_CMD="$CREATE_CMD --environment Variables='$ENV_VARS'"
    fi

    # Execute create command
    eval $CREATE_CMD
fi

# Step 7: Verify creation
echo "7. Verifying function creation..."
TARGET_ARN=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$TARGET_REGION" \
    --query 'Configuration.FunctionArn' \
    --output text)

echo ""
echo "Success! Function duplicated:"
echo "Source ARN: $SOURCE_ARN"
echo "Target ARN: $TARGET_ARN"
echo "Cache location: $BACKUP_DIR"

# Display next steps
echo ""
echo "Next steps:"
echo "1. Verify IAM role permissions work in $TARGET_REGION"
echo "2. Test function execution"
echo "3. Update CloudFormation parameter with new ARN:"
echo "   AzureIdentityLambdaArn: $TARGET_ARN"
echo ""
echo "Cache management:"
echo "- Cached files are stored in: $BACKUP_DIR"
echo "- Use --force-refresh to download fresh copy from AWS"
echo "- Delete cache directory to start fresh"