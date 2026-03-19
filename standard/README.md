# ec2 infra - CloudFormation Templates

This directory contains AWS CloudFormation templates for provisioning Rapticore infrastructure. Templates are organized into **active EKS templates** and **legacy EC2 templates**.

## Overview

```
                         ┌─────────────────────┐
                         │   StandardStack.yaml │  Per-tenant AWS resources
                         │  (SQS, S3, Cognito,  │  (deploy once per tenant)
                         │   EventBridge, CRS)   │
                         └──────────┬────────────┘
                                    │
                                    │ Tenant resources ready
                                    ▼
               ┌────────────────────────────────────────┐
               │         EKS Cluster (one-time)          │
               │                                        │
               │  ┌──────────────────────┐              │
               │  │ EksClusterStack.yaml │              │
               │  │  (IAM, EKS cluster,  │              │
               │  │   OIDC, add-ons,     │              │
               │  │   LB controller IAM) │              │
               │  └──────────┬───────────┘              │
               │             │                          │
               │             ▼                          │
               │  ┌────────────────────────┐            │
               │  │ EksNodeGroupStack.yaml │            │
               │  │  (on-demand + spot     │            │
               │  │   node groups)         │            │
               │  └──────────┬─────────────┘            │
               └─────────────┼──────────────────────────┘
                             │
                             │ Nodes ready
                             ▼
                  ┌─────────────────────┐
                  │   Helm Deployment    │  Per-tenant app deployment
                  │  (Freemium/helm/)    │  (see Freemium/README.md)
                  └─────────────────────┘
```

### Deployment Order

1. **`StandardStack.yaml`** - Deploy once per tenant (creates SQS, S3, Cognito, EventBridge)
2. **`EksClusterStack.yaml`** - Deploy once per account (creates the EKS cluster)
3. **`EksNodeGroupStack.yaml`** - Deploy once per account (creates worker nodes)
4. **Helm chart** (`Freemium/helm/rapticore-tenant/`) - Deploy once per tenant

---

## StandardStack.yaml

**Purpose:** Creates the foundational per-tenant AWS resources. This template is used by both the legacy EC2 and current EKS deployments - the resources it creates are compute-agnostic.

**Deploy as:** `rapticore-<TENANT_ID>` (e.g., `rapticore-acmecorp`)

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `VpcId` | *(required)* | VPC for the deployment |
| `Domain` | *(required)* | Full domain (e.g., `acmecorp.ore.rapticore.cloud`) |
| `HostedZoneID` | *(required)* | Route 53 hosted zone for domain records |
| `AzureIdentityLambdaArn` | *(required)* | Lambda ARN for Azure identity pool creation |
| `TenantId` | *(required)* | Unique tenant identifier |
| `CognitoGroupName` | *(required)* | Cognito group name (recommended: same as TenantId) |
| `CrsAccountId` | `422753814403` | AWS Account ID where CRS runs |
| `CognitoManagementRoleArn` | `arn:aws:iam::422753814403:role/cognito-management-for-standard-tenants` | Cross-account Cognito management role |
| `SharedUserPoolId` | `us-west-2_ugQoEHBWd` | Shared Cognito User Pool ID |
| `SharedUserPoolClientId` | `3c0adcuesr3fjrc1tri6g78uf` | Shared Cognito User Pool Client ID |
| `MonitoredAccountIds` | `422753814403` | AWS Account IDs for EventBridge monitoring |
| `EventBusName` | `RapticoreEventBus` | Custom EventBridge bus name |
| `AzureTenantId` | *(empty)* | Azure Tenant ID (GUID, optional) |
| `QueuesToDelete` | *(empty)* | Comma-separated SQS Queue ARNs to clean up |

### Resources Created

```
StandardStack
├── TLS Certificate
│   └── ACM Certificate (DNS-validated)
│
├── SQS Queues (each with a Dead Letter Queue)
│   ├── rapticore-vulnerability-<TENANT_ID>
│   ├── rapticore-container-vulnerability-<TENANT_ID>
│   ├── rapticore-resource-vulnerability-summary-<TENANT_ID>
│   ├── rapticore-reactive-remediation-<TENANT_ID>
│   ├── real-time-threat-alert-trigger-<TENANT_ID>
│   ├── real-time-threat-alert-trigger-azure-<TENANT_ID>  (conditional: Azure only)
│   ├── vcs-trigger-appsec-<TENANT_ID>
│   └── vcs-trigger-post-scan-<TENANT_ID>
│
├── S3 Buckets
│   └── vcs-content-<TENANT_ID>
│
├── EventBridge
│   └── Rapticore<TENANT_ID>ReceiverRule (routes events to SQS)
│
├── Azure Workload Identity (conditional: when AzureTenantId is set)
│   ├── OIDC Provider for Azure AD
│   ├── IAM Role for Azure RTTM with SQS permissions
│   └── Cognito Identity Pool + developer provider
│
├── CRS Cross-Account Authentication
│   ├── CrsServiceUserPassword (Secrets Manager, auto-generated)
│   ├── CrsUserManagementFunction (Lambda, creates Cognito user)
│   ├── CRS service user in shared Cognito User Pool
│   └── CrsCredentials (Secrets Manager, full auth config)
│
└── Queue Deletion Utility
    ├── QueueDeletionFunction (Lambda)
    └── DeleteSpecifiedQueues (Custom Resource)
```

### Key Outputs

| Output | Description |
|--------|-------------|
| `RapticoreStandardURL` | `https://<domain>` |
| `VulnerabilityQueueURL` | SQS queue URL for vulnerability findings |
| `ContainerVulnerabilityQueueURL` | SQS queue URL for container vulnerabilities |
| `ResourceVulnerabilitySummaryQueueURL` | SQS queue URL for resource summaries |
| `ReactiveRemediationQueueURL` | SQS queue URL for remediation actions |
| `RealTimeThreatAlertTriggerQueueURL` | SQS queue URL for real-time threat events |
| `VcsTriggerAppSecQueueURL` | SQS queue URL for VCS AppSec triggers |
| `VcsTriggerPostScanQueueURL` | SQS queue URL for VCS post-scan triggers |
| `VcsContentBucketName` | S3 bucket name for VCS content |
| `AzureWorkloadIdentityPoolId` | Cognito Identity Pool ID for Azure |
| `CreatedIdentityId` | Identity ID for Azure onboarding |
| `CrsServiceUsername` | CRS service user email in Cognito |
| `CrsRoleArn` | Cross-account IAM role ARN for CRS |
| `CrsCredentialsSecret` | Secrets Manager ARN for CRS credentials |
| `RealTimeThreatAlertTriggerAzureQueueURL` | SQS queue URL for Azure real-time threats *(conditional: Azure only)* |
| `QueueDeletionResults` | Results from queue deletion custom resource |

These outputs are consumed by `Freemium/bin/generate-eks-values.sh` to auto-populate Helm values.

---

## EksClusterStack.yaml

**Purpose:** Creates the EKS cluster and its supporting infrastructure. This is a **one-time deployment** per AWS account - all tenants share the same cluster.

**Deploy as:** `rapticore-eks-cluster`

### What is EKS?

Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service. Instead of running all services on a single EC2 instance with docker-compose, EKS distributes workloads as containers (pods) across multiple worker nodes. AWS manages the Kubernetes control plane (API server, etcd, scheduler), while you manage the worker nodes that run your application pods.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ClusterName` | `rapticore-eks` | Name of the EKS cluster |
| `KubernetesVersion` | `1.35` | Kubernetes version (1.32-1.35) |
| `VpcId` | *(required)* | VPC ID |
| `SubnetIds` | *(required)* | At least 2 subnets in different AZs |
| `EndpointPublicAccess` | `true` | Enable public API endpoint |
| `EndpointPrivateAccess` | `true` | Enable private API endpoint |

### Resources Created

```
EksClusterStack
├── IAM Roles
│   ├── EKS Cluster Role (AmazonEKSClusterPolicy, AmazonEKSVPCResourceController)
│   ├── EKS Node Role (worker node permissions: SQS, S3, Bedrock, SES, AssumeRole)
│   ├── EBS CSI Driver Role (IRSA - for persistent volumes)
│   ├── Application Pods Role (Pod Identity - SQS, S3, Bedrock, SES)
│   └── AWS Load Balancer Controller Role (IRSA - for NLB/ALB management)
│       Note: CloudFormation creates the IAM role only. The controller
│       itself is installed via Helm by setup-eks-cluster.sh.
│
├── Security Group
│   └── Cluster SG (HTTPS ingress + internal communication)
│
├── EKS Cluster
│   └── Full API/audit/authenticator/controller/scheduler logging
│
├── EKS Add-ons
│   ├── vpc-cni (pod networking)
│   ├── coredns (DNS resolution)
│   ├── kube-proxy (service networking)
│   ├── aws-ebs-csi-driver (persistent volumes)
│   └── eks-pod-identity-agent (AWS credential injection)
│
├── OIDC Provider (for IRSA - IAM Roles for Service Accounts)
│
└── Instance Profile (for node group EC2 instances)
```

### Key Outputs

| Output | Description |
|--------|-------------|
| `ClusterName` | EKS cluster name |
| `ClusterArn` | EKS cluster ARN |
| `ClusterEndpoint` | API server endpoint URL |
| `ClusterSecurityGroupId` | Cluster security group ID |
| `NodeRoleArn` | IAM role ARN for worker nodes (input to EksNodeGroupStack) |
| `NodeInstanceProfileArn` | Instance profile ARN for node group EC2 instances |
| `OidcProviderArn` | OIDC provider ARN for IRSA |
| `OidcProviderUrl` | OIDC provider URL (without `https://` prefix) |
| `AwsLoadBalancerControllerRoleArn` | IAM role for LB controller (input to Helm) |
| `ApplicationPodsRoleArn` | IAM role for app pods via Pod Identity |
| `VpcId` | VPC ID used by the cluster |
| `SubnetIds` | Subnet IDs used by the cluster |

---

## EksNodeGroupStack.yaml

**Purpose:** Creates the EKS managed node groups (worker nodes). Deploy after the cluster stack.

**Deploy as:** `rapticore-eks-nodes`

### What are Node Groups?

Node groups are sets of EC2 instances that run as Kubernetes worker nodes. EKS manages their lifecycle (provisioning, updates, replacements). This template creates two node groups:

1. **On-demand node group** - Reliable, always-available instances for production workloads
2. **Spot node group** - Cost-optimized instances (up to 90% savings) for fault-tolerant workloads. Starts at 0 instances (scaled up as needed). Has a `PREFER_NO_SCHEDULE` taint so workloads only land here if explicitly tolerating spot interruptions.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ClusterName` | `rapticore-eks` | Must match the cluster stack |
| `NodeGroupName` | `rapticore-nodes` | Name for the node group |
| `NodeRoleArn` | *(required)* | From `EksClusterStack` output `NodeRoleArn` |
| `SubnetIds` | *(required)* | Same subnets as the cluster |
| `InstanceTypes` | `t4g.large, t4g.xlarge, m7g.large` | ARM Graviton instance types |
| `DiskSize` | `50` | Root volume size in GB |
| `DesiredSize` | `2` | Initial node count |
| `MinSize` / `MaxSize` | `1` / `10` | Autoscaling bounds |
| `CapacityType` | `ON_DEMAND` | `ON_DEMAND` or `SPOT` |
| `AmiType` | `AL2023_ARM_64_STANDARD` | Amazon Linux 2023 ARM64 |

### Instance Types

The default configuration uses **ARM Graviton** instances for better price-performance:

| Instance Type | vCPU | Memory | Use Case |
|---------------|------|--------|----------|
| `t4g.large` | 2 | 8 GiB | Small tenants (1-2 tenants) |
| `t4g.xlarge` | 4 | 16 GiB | Medium tenants |
| `m7g.large` | 2 | 8 GiB | Compute-stable workloads |

### Key Outputs

| Output | Description |
|--------|-------------|
| `NodeGroupName` | Primary node group name |
| `NodeGroupArn` | Primary node group ARN |
| `SpotNodeGroupName` | Spot node group name |
| `SpotNodeGroupArn` | Spot node group ARN |

---

## Legacy Templates (Deprecated)

> The following templates are from the original EC2-based deployment architecture. They are kept for reference and for existing EC2 tenants that have not yet been migrated to EKS. **Do not use these for new deployments.**

### StandardEC2InstanceOnly.yml (DEPRECATED)

**Replaced by:** `EksClusterStack.yaml` + `EksNodeGroupStack.yaml` + Helm chart

Creates a single EC2 instance running docker-compose with all Rapticore services. Includes:
- Security Group (ports 80, 443, 6100)
- EC2 Instance with IAM role (SQS, S3, AssumeRole, SES permissions)
- NLB + Target Group
- Route53 DNS record
- Cognito Identity Pool for Azure

### StandardEC2InstanceOnlyWithNewVPCStack.yaml (DEPRECATED)

**Replaced by:** VPC created separately + `EksClusterStack.yaml` + `EksNodeGroupStack.yaml`

Same as `StandardEC2InstanceOnly.yml` but also creates a new VPC with networking. Used for accounts that don't have an existing Rapticore VPC.

### StandardVpcOnlyInfrastructure.yaml (DEPRECATED)

**Replaced by:** VPC created separately (or reuse existing VPC with EKS)

Creates only VPC infrastructure:
- VPC (`10.0.0.0/16`)
- Public subnet
- Internet Gateway
- Route table
- Security group

---

## setup-azure-identity-pool-lambda/

**Purpose:** Utility for duplicating the Azure Identity Pool Lambda function. Contains:

- `README.md` - Setup instructions
- `duplicate-lambda.sh` - Script to duplicate the Lambda function
- `lambda-backup/` - Lambda function code backup

The Lambda function (`Azure-Identity-pool-lambda`) is referenced in `StandardStack.yaml` as the `AzureIdentityLambdaArn` parameter. It creates Azure identities by requesting tokens from Cognito Identity Pools. This Lambda only needs to exist once per account - the script is for setting up new accounts.

---

## Deployment Cheat Sheet

### New tenant on existing EKS cluster:
```bash
# 1. Deploy StandardStack via CloudFormation console
#    Template: StandardStack.yaml
#    Stack name: rapticore-<TENANT_ID>

# 2. Validate ACM certificate (see ACM console)

# 3. Generate Helm values + deploy
cd Freemium
./bin/deploy-eks-tenant.sh <TENANT_ID>
```

### New account (no EKS cluster yet):
```bash
# 1. Deploy EKS cluster
cd Freemium
./bin/setup-eks-cluster.sh \
  --vpc-id <VPC_ID> \
  --subnet-ids "<SUBNET_1>,<SUBNET_2>" \
  --template-dir "../ec2 infra"

# 2. Then follow "New tenant" steps above
```

### Migrating tenant from EC2 to EKS:
```bash
# 1. Deploy tenant on EKS (Steps 1-3 above)

# 2. Export data from EC2 PostgreSQL
ssh ec2-instance "pg_dump -U postgres rapticore > /tmp/backup.sql"
scp ec2-instance:/tmp/backup.sql .

# 3. Import data to EKS
./bin/migrate-tenant-data.sh <TENANT_ID> backup.sql

# 4. Verify EKS deployment, then cutover DNS
./bin/cutover-dns.sh <TENANT_ID>
```
