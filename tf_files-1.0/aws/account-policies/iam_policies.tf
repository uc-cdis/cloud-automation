locals  {
  all_iam_policies = [
    # admin policy attachments
    { role = "admins", policy = "arn:aws:iam::aws:policy/AdministratorAccess" },
    # bsdisocyber policy attachments
    { role = "bsdisocyber", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Config_Read_List" },
    { role = "bsdisocyber", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Logs_Read" },
    # bsdisorisk policy attachments
    { role = "bsdisorisk", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Config_Read_List" },
    { role = "bsdisorisk", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/IAMReadOnlyAccess" },
    { role = "bsdisorisk", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Logs_Read" },
    { role = "bsdisorisk", policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/TrustedAdvisor_List" },
    # devopsdirector policy attachments
    { role = "devopsdirector", policy = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess" },
    { role = "devopsdirector", policy = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AmazonRDSFullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AmazonRoute53FullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AmazonS3FullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AmazonVPCFullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess" },
    { role = "devopsdirector", policy= "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser" },
    { role = "devopsdirector", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DevOpsDirectorConsolidatedPolicies" },
    # devopsgdc policy attachments
    { role = "devopsgdc", policy = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess" },
    { role = "devopsgdc", policy = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AmazonRDSFullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AmazonRoute53FullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AmazonS3FullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AmazonVPCFullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess" },
    { role = "devopsgdc", policy= "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser" },
    { role = "devopsgdc", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DevOPSConsolidatedPolicies" },
    # devopsplanx policy attachments
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonEC2FullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonRDSFullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonRoute53FullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonS3FullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AmazonVPCFullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess" },
    { role = "devopsplanx", policy= "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser" },
    { role = "devopsplanx", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DevOPSConsolidatedPolicies" },
    { role = "devopsplanx", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/CtdsKmsSuper" },
    #{ role = "devopsplanx", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DevOpsTroubleShooting_CLIFunctions" },
    # projectmanagergdc policy attachments
    { role = "projectmanagergdc", policy= "arn:aws:iam::aws:policy/job-function/Billing" },
    { role = "projectmanagergdc", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Config_Read_List" },
    { role = "projectmanagergdc", policy= "arn:aws:iam::aws:policy/IAMReadOnlyAccess" },
    # projectmanagerplanx policy attachments
    { role = "projectmanagerplanx", policy= "arn:aws:iam::aws:policy/job-function/Billing" },
    { role = "projectmanagerplanx", policy= "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Config_Read_List" },
    { role = "projectmanagerplanx", policy= "arn:aws:iam::aws:policy/IAMReadOnlyAccess" },
  ]
  # Filter out what policies we actually want to attach based on the roles we are creating
  relevant_iam_policies = [for x in local.all_iam_policies: {role = x.role, policy = x.policy} if contains(var.roles, x.role)]

}

resource "aws_iam_policy" "policy" {
  for_each = fileset("${path.module}/custom_iam_policies", "*")
  name        =  split(".", each.value)[0]
  path        = "/"
  policy = file("${path.module}/custom_iam_policies/${each.value}")
}


resource "aws_iam_role" "role" {
  count = length(var.roles)
  name  = var.roles[count.index]

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithSAML",
      "Effect": "Allow",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      },
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/UChicagoIdP"
      }
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "policy_attachment" {
  depends_on = [
    aws_iam_role.role,
    aws_iam_policy.policy
  ]
  count = length(local.relevant_iam_policies)
  role       = local.relevant_iam_policies[count.index].role
  policy_arn = local.relevant_iam_policies[count.index].policy
}




