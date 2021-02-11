# aws-onboarding
AWS Cloud Account Onboarding for Rapticore


Deploy the CloudFormation stack in this repository to create the AWS IAM role allowing Cross-Account access from your Rapticore environment.

You will need the _Rapticore Source Role ARN_ (a CloudFormation template Parameter) which will be provided as part of your Rapticore setup and onboarding. 

Deployment Options:

1 - AWS Console
- Log into your target AWS account with permissions to create IAM Roles
- Go to Services --> Cloudformation.
- Click Create Stack button on the top right corner of the screen. Selecting "With new resources(Standard)" 
- Under Create Stack - select Template is Ready and then Select "Upload a template file." 
- Choose File to the YAML file included here and click Next.
- Under Specific Stack details:
    - Enter a Friendly Name for the stack e.g., Rapticore-cloud-extractor-role-stack
    - Enter RapticoreAccountId provided to you by Rapticcore.
    - Enter RapticoreTenantId provided to you by Rapticore.
    - Click Next. 
    - Review Details and select the acknowledgment checkbox once in agreement. 
    - Click Create
    - Review Progress, and once the Role is created, copy the Role ARN and enter it in the Rapticore portal or enter it in a CSV for bulk upload.
    
2. AWS Commandline Deployment. 
- You must have AWS CLI configure an AWS account Profiles created for all target accounts for deploying the stack using the aws cli. Please consult AWS documentation on AWS cli installation and configure AWS profiles. 
- Once profiles are set. Run the following command replacing:
  - RAPTICOREACOUNTID
  - RAPTICORETENANTID
  - PROFILE_NAME

aws cloudformation deploy --template-file ./RapticoreCrossAccountStack.json --stack-name aws-discovery-mwf4-account --parameter-overrides RapticoreAccountId='RAPTICOREACOUNTID' RapticoreTenantId='RAPTICORETENANTID' --tags Name=aws-discovery --capabilities CAPABILITY_NAMED_IAM --profile PROFILE_NAME region us-east-1
