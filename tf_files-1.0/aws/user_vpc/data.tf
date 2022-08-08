data "template_file" "ssh_config" {
  template = file("${path.module}/ssh_config.tpl")

  vars {
    vpc_name        = var.vpc_name
    login_public_ip = aws_eip.login.public_ip
  }
}
