################################################################################
# Install Gateway API CRDs
################################################################################
resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
  }

  depends_on = [module.eks, null_resource.update_kubeconfig]
}

################################################################################
# Create aws-load-balancer-system namespace
################################################################################
resource "kubernetes_namespace" "aws_load_balancer_system" {
  metadata {
    name = "aws-load-balancer-system"
    labels = {
      name = "aws-load-balancer-system"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# IAM Role for AWS Load Balancer Controller
################################################################################
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:aws-load-balancer-system:aws-load-balancer-controller"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.cluster_name}-aws-load-balancer-controller"
    Terraform = "true"
  }
}

################################################################################
# Data source for AWS Load Balancer Controller IAM Policy
################################################################################
data "http" "aws_load_balancer_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}

################################################################################
# IAM Policy for AWS Load Balancer Controller (from official source)
################################################################################
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.aws_load_balancer_controller_policy.response_body

  tags = {
    Name      = "${var.cluster_name}-aws-load-balancer-controller"
    Terraform = "true"
  }
}

################################################################################
# IAM Policy Attachment for AWS Load Balancer Controller
################################################################################
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

################################################################################
# Install AWS Load Balancer Controller using Helm
################################################################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = kubernetes_namespace.aws_load_balancer_system.metadata[0].name
  version    = "1.8.1"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
        }
      }
      region                      = var.aws_region
      vpcId                       = module.vpc.vpc_id
      enableServiceMutatorWebhook = false
    })
  ]

  depends_on = [
    kubernetes_namespace.aws_load_balancer_system,
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
    null_resource.gateway_api_crds
  ]
}

################################################################################
# Output for manual DNS configuration
################################################################################
output "gateway_dns_instructions" {
  description = "Instructions for configuring DNS after Gateway deployment"
  value = {
    message = "After deploying the Gateway resources, get the LoadBalancer hostname with: kubectl get gateway app-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'"
    route53_zone_id = data.aws_route53_zone.main.zone_id
    subdomain = var.app_subdomain
    domain = var.domain_name
  }
}
