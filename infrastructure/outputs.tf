output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

################################################################################
# Node.js App DNS Outputs
################################################################################
output "nodejs_app_dns_info" {
  description = "Node.js application DNS configuration information"
  value = {
    domain_name    = var.domain_name
    subdomain      = var.app_subdomain
    full_hostname  = "${var.app_subdomain}.${var.domain_name}"
    app_url        = "http://${var.app_subdomain}.${var.domain_name}"
    hosted_zone_id = data.aws_route53_zone.main.zone_id
    nlb_hostname   = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname

    # Hostname-based routing subdomains (Part_01)
    app1_hostname = "${var.app1_subdomain}.${var.domain_name}"
    app1_url      = "http://${var.app1_subdomain}.${var.domain_name}"
    app2_hostname = "${var.app2_subdomain}.${var.domain_name}"
    app2_url      = "http://${var.app2_subdomain}.${var.domain_name}"
  }
}
