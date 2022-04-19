output "vm_name" {
  value = "${lookup(data.aws_instance.worker.tags,"Name")}"
}

