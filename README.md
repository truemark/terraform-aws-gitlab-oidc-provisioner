# AWS GitLab OIDC Provisioner

This module will create an IAM role that can be assumed by GitLab CI/CD jobs using OpenID Connect (OIDC), eliminating the need for static AWS credentials.

## Prerequisites

- An existing GitLab OIDC identity provider in your AWS account
- GitLab project(s) that need AWS access

## Features

- Creates IAM role for GitLab OIDC authentication
- Optional Terraform S3/DynamoDB state management policies
- Configurable trust policies and conditions
- Support for multiple GitLab projects/groups

## Usage

### Basic Usage (Minimum Required Configuration)

```hcl
module "gitlab_oidc_provisioner" {
  source = "./terraform-aws-gitlab-oidc-provisioner"
  
  # REQUIRED: Must specify GitLab projects/groups that can assume this role
  subjects = [
    "project_path:mygroup/myproject:ref_type:branch:ref:main",
    "project_path:mygroup/myproject:ref_type:branch:ref:develop"
  ]
}
```

### Complete Configuration Example

```hcl
module "gitlab_oidc_provisioner" {
  source = "./terraform-aws-gitlab-oidc-provisioner"
  
  # Required Configuration
  subjects = [
    "project_path:mygroup/myproject:ref_type:branch:ref:main",
    "project_path:mygroup/*:ref_type:branch:ref:*"
  ]
  
  # Optional Configuration (with defaults shown)
  role_name               = "my-gitlab-ci-role"        # default: "gitlab-provisioner"
  description            = "Custom GitLab CI role"     # default: "gitlab-provisioner"
  provider_url           = "https://gitlab.example.com" # default: "https://gitlab.com"
  path                   = "/gitlab/"                   # default: "/"
  create_role            = true                         # default: true
  force_detach_policies  = false                       # default: false
  allow_self_assume_role = true                         # default: true
  max_session_duration   = 3600                        # default: 22200 (6h 10m)
  
  # Optional: Add custom policies
  role_policy_arns = {
    s3_read = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ec2_read = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  }
  
  # Optional: Terraform state management
  create_terraform_policy = true                       # default: true
  terraform_s3_bucket     = "my-terraform-state"      # default: auto-generated
  terraform_s3_prefix     = "myproject"               # default: "*"
  terraform_dynamodb_table = "my-terraform-locks"     # default: auto-generated
  
  # Optional: Additional inline policies
  policies = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:GetObject"]
          Resource = "arn:aws:s3:::my-bucket/*"
        }
      ]
    })
  ]
  
  # Optional: Tags
  tags = {
    Environment = "production"
    Team        = "devops"
    Project     = "myproject"
  }
  
  terraform_policy_tags = {
    Purpose = "terraform-state-access"
  }
}
```

### Required Variables

The following variables **must** be provided (no defaults or require meaningful values):

- **`subjects`**: List of GitLab project paths with specific format:
  - Format: `"project_path:group/project:ref_type:branch:ref:branch_name"`
  - Examples:
    - `"project_path:mygroup/myproject:ref_type:branch:ref:main"`
    - `"project_path:mygroup/*:ref_type:branch:ref:*"` (wildcard for all projects/branches)

## GitLab CI/CD Configuration

In your GitLab CI/CD pipeline, configure the ID token and assume the role:

```yaml
assume_aws_role:
  image: amazon/aws-cli:latest
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: https://gitlab.com
  script:
    - export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
        $(aws sts assume-role-with-web-identity \
        --role-arn ${AWS_ROLE_ARN} \
        --role-session-name "GitLabRunner-${CI_PROJECT_ID}-${CI_PIPELINE_ID}" \
        --web-identity-token $GITLAB_OIDC_TOKEN \
        --duration-seconds 3600 \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text))
    - aws sts get-caller-identity
```

## Related Links