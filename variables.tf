variable "create_role" {
  description = "Whether to create role"
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name to use on resources"
  type        = string
  default     = "gitlab-provisioner"
}

variable "description" {
  description = "Assumable Role used by GitLab for CI/CD with authorized project groups. See subjects for details."
  type        = string
  default     = "gitlab-provisioner"
}

variable "path" {
  description = "Path to use on resources"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "force_detach_policies" {
  description = "Whether policies should be detached from this role when destroying"
  type        = bool
  default     = false
}

variable "provider_url" {
  description = "The URL of the identity provider. Corresponds to the iss claim. Use https://gitlab.com for GitLab SaaS or your GitLab instance URL"
  type        = string
  default     = "https://gitlab.com"
}

variable "role_policy_arns" {
  description = "List of ARNs of IAM policies to attach to IAM role"
  type        = map(string)
  default     = {}
}

variable "subjects" {
  description = "List of GitLab projects/groups allowed to use this role. Specify as 'group/project' or 'group/*' for all projects in group."
  type        = list(string)
  default     = []
}

variable "create_terraform_policy" {
  description = "Whether to create the policy for terraform access to S3 and Dynamo"
  type        = bool
  default     = true
}

variable "terraform_s3_bucket" {
  description = "Name of the terraform bucket holding terraform state information. Defaults to <account>-terraform-<region>."
  default     = null
  type        = string
}

variable "terraform_s3_prefix" {
  description = "Optional path prefix inside the terraform S3 bucket to grant access to."
  default     = "*"
  type        = string
}

variable "terraform_dynamodb_table" {
  description = "Name of the DynamoDB table holding terraform locks. Defaults to <account>-terraform-<region>."
  default     = null
  type        = string
}

variable "terraform_policy_tags" {
  description = "Tags to add to the terraform policy"
  type        = map(string)
  default     = {}
}

variable "policies" {
  description = "Policies to create and apply to the IAM user."
  default     = []
  type        = list(string)
}

variable "allow_self_assume_role" {
  description = "Allow the role to assume itself"
  default     = true
  type        = bool
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds between 3600 and 43200"
  default     = 22200 # 6 hours 10 minutes. 6 hours is the maximum session duration for a GitLab CI/CD job
  type        = number
}