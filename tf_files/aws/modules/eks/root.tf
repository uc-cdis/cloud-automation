
data "template_file" "kube_config" {
  template = "${file("${path.module}/kubeconfig.tpl")}"

  vars {
    vpc_name     = "${var.vpc_name}"
    eks_name     = "${aws_eks_cluster.eks_cluster.id}"
    eks_endpoint = "${aws_eks_cluster.eks_cluster.endpoint}"
    eks_cert     = "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
  }
}

