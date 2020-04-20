

data "aws_ami" "qualys_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*${var.image_name_search_criteria}*"]
  }
  filter {
    name   = "description"
    values = ["${var.image_desc_search_criteria}*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

#  filter {
#    name   = "root-device-type"
#    values = ["ebs"]
#  }

  owners = ["${var.ami_account_id}"]

}
