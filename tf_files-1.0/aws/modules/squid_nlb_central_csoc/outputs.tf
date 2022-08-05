output "squid_nlb_dns_name" {
  value = aws_lb.squid_nlb.dns_name
}

output "vpc_endpoint_service_name" {
  value = aws_vpc_endpoint_service.squid_nlb.service_name
}
