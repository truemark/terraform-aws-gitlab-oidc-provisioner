output "role_name" {
  value = var.create_role ? aws_iam_role.gitlab_provisioner[0].name : null
}

output "role_arn" {
  value = var.create_role ? aws_iam_role.gitlab_provisioner[0].arn : null
}

output "role_id" {
  value = var.create_role ? aws_iam_role.gitlab_provisioner[0].unique_id : null
}

output "role_path" {
  value = var.create_role ? aws_iam_role.gitlab_provisioner[0].path : null
}

output "terraform_policy_name" {
  value = join("", aws_iam_policy.terraform.*.name)
}

output "terraform_policy_arn" {
  value = join("", aws_iam_policy.terraform.*.arn)
}

output "terraform_policy_id" {
  value = join("", aws_iam_policy.terraform.*.id)
}