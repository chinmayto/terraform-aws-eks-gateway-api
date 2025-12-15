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
# Gateway API Outputs
################################################################################
output "gateway_service_info" {
  description = "Gateway API service information"
  value = {
    namespace    = "gateway-system"
    gateway_name = "app-gateway"
    service_type = "LoadBalancer"
  }
}

output "gateway_access_info" {
  description = "Gateway API access information"
  value = {
    gateway_class = "aws-load-balancer-controller"
    controller    = "gateway.aws.com/controller"
    gateway_name  = "app-gateway"
    gateway_namespace = "gateway-system"
    get_loadbalancer_command = "kubectl get gateway app-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'"
  }
}

output "aws_load_balancer_controller_info" {
  description = "AWS Load Balancer Controller information"
  value = {
    namespace       = kubernetes_namespace.aws_load_balancer_system.metadata[0].name
    service_account = "aws-load-balancer-controller"
    iam_role_arn    = aws_iam_role.aws_load_balancer_controller.arn
    iam_role_name   = aws_iam_role.aws_load_balancer_controller.name
    iam_policy_arn  = aws_iam_policy.aws_load_balancer_controller.arn
    helm_release    = helm_release.aws_load_balancer_controller.name
    chart_version   = helm_release.aws_load_balancer_controller.version
  }
}

################################################################################
# Node.js App DNS Outputs
################################################################################
output "nodejs_app_dns_info" {
  description = "Node.js application DNS configuration information"
  value = {
    domain_name     = var.domain_name
    subdomain       = var.app_subdomain
    full_hostname   = "${var.app_subdomain}.${var.domain_name}"
    app_url         = "http://${var.app_subdomain}.${var.domain_name}"
    dns_record_type = "A (Alias to Gateway API LoadBalancer)"
  }
}
