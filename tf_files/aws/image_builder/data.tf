data "aws_ami" "eksoptimized" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.base_image}"]
  }
}
