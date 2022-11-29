#The name of the role
rolename=""

#A description of the role
description="Role created with gen3 awsrole"

#A path to attach to the role. For more information, see:
#https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-friendly-names
path="/gen3_service/"

#Assume-role policy to attach to the role
ar_policy = <<EOR
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}

EOR
