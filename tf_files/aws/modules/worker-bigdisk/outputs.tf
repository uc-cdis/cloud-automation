output "vm_name" {
  value = "${aws_instance.worker.tag:Name}"
}

