output "peer1_state_details" {
  value = "${module.vpc-peering.peer1_state_details}"
}

output "peer1_vpc_state" {
  value = "${module.vpc-peering.peer1_vpc_state}"
}

output "peer2_state_details" {
  value = "${module.vpc-peering.peer2_state_details}"
}

output "peer2_vpc_state" {
  value = "${module.vpc-peering.peer2_vpc_state}"
}