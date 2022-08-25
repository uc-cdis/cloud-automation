# this module would create a new ebs volume and attach it to a particular instance
resource "aws_ebs_volume" "worker_extra_drive" {
    availability_zone = data.aws_instance.worker.availability_zone
    encrypted         = true
    size              = var.volume_size

    tags = {
        Name = "${lookup(data.aws_instance.worker.tags,"Name")}_extravolume_${length(data.aws_instance.worker.ebs_block_device) + 1}"
    }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = var.dev_name
  volume_id   = aws_ebs_volume.worker_extra_drive.id
  instance_id = data.aws_instance.worker.id
}
