data "template_file" "ssh_keys" {
  template = "${file("${path.module}/../../../../files/authorized_keys/ops_team")}"
}

data "template_file" "bootstrap" {
  template = "${file("${path.module}/../../../../flavors/eks/${var.bootstrap_script}")}"
  vars {
    #eks_ca       = "${data.aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
    #eks_endpoint = "${data.aws_eks_cluster.eks_cluster.endpoint}"
    eks_ca        = "${var.eks_cluster_ca}"
    eks_endpoint  = "${var.eks_cluster_endpoint}"
    eks_region    = "${data.aws_region.current.name}"
    vpc_name      = "${var.vpc_name}"
    ssh_keys      = "${data.template_file.ssh_keys.rendered}"
    nodepool      = "${var.nodepool}"
    kernel        = "${var.kernel}"
    activation_id = "${var.activation_id}"
    customer_id   = "${var.customer_id}"
  }
}
