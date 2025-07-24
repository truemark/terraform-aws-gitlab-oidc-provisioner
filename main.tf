data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

#------------------------------------------------------------------------------
# OIDC Assumable Role - GitLab
#------------------------------------------------------------------------------

data "aws_iam_openid_connect_provider" "gitlab" {
  url = var.provider_url
}

data "aws_iam_policy_document" "assume_role_with_oidc" {
  count = var.create_role ? 1 : 0

  dynamic "statement" {
    # https://aws.amazon.com/blogs/security/announcing-an-update-to-iam-role-trust-policy-behavior/
    for_each = var.allow_self_assume_role ? [1] : []

    content {
      sid     = "ExplicitSelfRoleAssumption"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role${var.path}${var.role_name}"]
      }
    }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "ForAnyValue:StringLike"
      values   = var.subjects
      variable = "gitlab.com:sub"
    }

    principals {
      identifiers = [data.aws_iam_openid_connect_provider.gitlab.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "gitlab_provisioner" {
  count = var.create_role ? 1 : 0

  name                  = var.role_name
  description           = var.description
  force_detach_policies = var.force_detach_policies
  path                  = var.path
  max_session_duration  = var.max_session_duration
  assume_role_policy    = data.aws_iam_policy_document.assume_role_with_oidc[0].json
  tags = merge({
    Role = var.role_name
  }, var.tags)
}

resource "aws_iam_role_policy_attachment" "gitlab_provisioner" {
  for_each = var.create_role && length(var.role_policy_arns) > 0 ? var.role_policy_arns : {}

  policy_arn = each.value
  role       = aws_iam_role.gitlab_provisioner[0].name
}

#------------------------------------------------------------------------------
# Terraform S3 Access
#------------------------------------------------------------------------------
# This policy grants the provisioner user access to specific paths in the S3
# bucket holding terraform state. This is needed to prevent different
# provisioner users from stepping on one another's changes. Additionally, there
# is sensitive information stored in the state files in these S3 buckets which should be restricted.

locals {
  terraform_s3_bucket      = var.terraform_s3_bucket == null ? "${data.aws_caller_identity.current.account_id}-terraform-${data.aws_region.current.region}" : var.terraform_s3_bucket
  terraform_dynamodb_table = var.terraform_dynamodb_table == null ? "${data.aws_caller_identity.current.account_id}-terraform-${data.aws_region.current.region}" : var.terraform_dynamodb_table
}

data "aws_iam_policy_document" "terraform" {
  statement {
    sid       = "AllowBucketList"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::*"]
  }
  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}"]
  }
  statement {
    sid       = "AllowPath"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListObjects"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}/${var.terraform_s3_prefix}/*"]
  }
  statement {
    sid       = "AllowWorkspacePath"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListObjects"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}/env:/*/${var.terraform_s3_prefix}/*"]
  }
  statement {
    sid       = "AllowDynamo"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${local.terraform_dynamodb_table}"]
  }
}

resource "aws_iam_policy" "terraform" {
  count       = var.create_role && var.create_terraform_policy ? 1 : 0
  name        = "${var.role_name}-terraform"
  description = "Allows access to terraform state and locks."
  policy      = data.aws_iam_policy_document.terraform.json
  tags        = merge(var.tags, var.terraform_policy_tags)
  path        = var.path
}

resource "aws_iam_role_policy_attachment" "terraform" {
  count      = var.create_role && var.create_terraform_policy ? 1 : 0
  policy_arn = aws_iam_policy.terraform[count.index].arn
  role       = aws_iam_role.gitlab_provisioner[0].name
}

#------------------------------------------------------------------------------
# Additional Policies
#------------------------------------------------------------------------------
resource "aws_iam_policy" "provisioner_n" {
  count       = length(var.policies)
  name        = "${var.role_name}-${count.index}"
  path        = var.path
  description = "Access policy for IAM role ${var.role_name}"
  policy      = var.policies[count.index]
}

resource "aws_iam_role_policy_attachment" "provisioner_n" {
  count      = length(var.policies)
  policy_arn = aws_iam_policy.provisioner_n[count.index].arn
  role       = aws_iam_role.gitlab_provisioner[0].name
}