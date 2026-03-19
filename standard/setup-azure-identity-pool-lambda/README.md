# Azure Identity Pool Lambda Setup

This directory contains tools for backing up and duplicating AWS Lambda functions across regions, specifically for Azure Identity Pool integration.

## Directory Structure

```
setup-azure-identity-pool-lambda/
├── duplicate-lambda.sh          # Main duplication script
├── lambda-backup/              # Persistent cache directory
│   ├── function.zip           # Lambda function code
│   ├── function-config.json   # Function configuration
│   └── metadata.json          # Backup metadata
└── README.md                  # This file
```

## Prerequisites

- AWS CLI installed and configured
- `jq` command-line JSON processor
- `curl` for downloading files
- Appropriate AWS permissions for Lambda operations

### Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq
```

## Usage

### Initial Setup

1. Create the directory and navigate to it:
```bash
mkdir setup-azure-identity-pool-lambda
cd setup-azure-identity-pool-lambda
```

2. Place the `duplicate-lambda.sh` script in this directory

3. Make the script executable:
```bash
chmod +x duplicate-lambda.sh
```

### Duplicate Lambda Function

#### First Run (Downloads and Caches)
```bash
./duplicate-lambda.sh arn:aws:lambda:us-west-2:123456789012:function:azure-identity-function ap-southeast-2
```

#### Subsequent Runs (Uses Cache)
```bash
./duplicate-lambda.sh arn:aws:lambda:us-west-2:123456789012:function:azure-identity-function eu-west-1
```

#### Force Fresh Download
```bash
./duplicate-lambda.sh arn:aws:lambda:us-west-2:123456789012:function:azure-identity-function ap-southeast-2 --force-refresh
```

## Features

### Intelligent Caching
- **First run**: Downloads from AWS and stores locally
- **Subsequent runs**: Uses cached files for faster deployment
- **Cache validation**: Displays cache info before use
- **Force refresh**: Option to bypass cache

### Offline Capability
- Deploy to multiple regions without re-downloading
- Backup survives AWS Lambda deletion
- Portable between environments

### Safety Features
- ARN validation
- Duplicate detection
- Update confirmation prompts
- Comprehensive error handling

## Cache Management

### View Cache Information
Cache metadata is stored in `lambda-backup/metadata.json`:
```bash
cat lambda-backup/metadata.json
```

### Clear Cache
```bash
rm -rf lambda-backup/
```

### Backup Cache
```bash
cp -r lambda-backup/ lambda-backup-$(date +%Y%m%d)/
```

## Troubleshooting

### IAM Role Issues
If the Lambda uses an IAM role, ensure it exists in the target region or update the role ARN in the function configuration.

### Environment Variables
Review environment variables in the deployed function for region-specific values.

### Network Connectivity
Ensure AWS CLI can reach both source and target regions.

## CloudFormation Integration

After successful duplication, update your CloudFormation template parameter:

```yaml
Parameters:
  AzureIdentityLambdaArn:
    Description: 'ARN of existing Lambda function'
    Type: String
    Default: 'arn:aws:lambda:ap-southeast-2:123456789012:function:azure-identity-function'
```

## Security Considerations

- Function code is stored locally in plain text
- Ensure proper file permissions on the backup directory
- Consider encrypting sensitive function code
- Review IAM policies for cross-region deployment