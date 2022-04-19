
# Create the kubeconfig file to talk to the cluster

data "template_file" "kube_config" {
  template = "${file("${path.module}/kubeconfig.tpl")}"

  vars {
    vpc_name     = "${var.vpc_name}"
    eks_name     = "${aws_eks_cluster.eks_cluster.id}"
    eks_endpoint = "${aws_eks_cluster.eks_cluster.endpoint}"
    eks_cert     = "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
  }
}


# Script that will run once the cluster is created, it'll apply a configmap to the cluster
# intended to give them permission to talk to the control plan and authenticate.

data "template_file" "init_cluster" {
  template = "${file("${path.module}/init_cluster.sh")}"

  vars {
    vpc_name        = "${var.vpc_name}"
    kubeconfig_path = "${var.vpc_name}_output_EKS/kubeconfig"
    auth_configmap  = "${var.vpc_name}_output_EKS/aws-auth-cm.yaml"
  }
}



# SSH keys to put into the worker nodes
 
data "template_file" "ssh_keys" {
  template = "${file("${path.module}/../../../../files/authorized_keys/ops_team")}"
}



# Script to initialize the worker nodes

data "template_file" "bootstrap" {
  template = "${file("${path.module}/../../../../flavors/eks/${var.bootstrap_script}")}"
  vars {
    eks_ca        = "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
    eks_endpoint  = "${aws_eks_cluster.eks_cluster.endpoint}"
    eks_region    = "${data.aws_region.current.name}"
    vpc_name      = "${var.vpc_name}"
    ssh_keys      = "${data.template_file.ssh_keys.rendered}"
    nodepool      = "default"
    activation_id = "${var.activation_id}"
    customer_id   = "${var.customer_id}"
  }
}
