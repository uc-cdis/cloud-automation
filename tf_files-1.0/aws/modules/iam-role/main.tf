resource "aws_iam_role" "the_role" {
  name                  = var.role_name
  description           = var.role_description
  assume_role_policy    = var.role_assume_role_policy
  force_detach_policies = var.role_force_detach_policies
  tags                  = var.role_tags
}
