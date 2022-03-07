output "fetched_AMI_Id" {
data "aws_ami" "eksoptimized" {
  value = data.aws_ami.eksoptimized.image_id
}
