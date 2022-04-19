output "squid_nlb_dns_name" {
  value = "${module.squid_nlb.squid_nlb_dns_name}"
}

output "vpc_endpoint_service_name" {
  value = "${module.squid_nlb.vpc_endpoint_service_name}"
}
