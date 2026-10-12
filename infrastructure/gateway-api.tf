################################################################################
# Install Gateway API CRDs (standard channel v1.2.1)
# Traefik v3.3 supports Gateway API standard v1.2.1.
# Must be applied before Traefik so the GatewayClass/Gateway/HTTPRoute CRDs
# exist when Traefik starts up and tries to watch them.
################################################################################
resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = "kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml"
  }

  depends_on = [module.eks, null_resource.update_kubeconfig]
}

################################################################################
# Namespace for Traefik
################################################################################
resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
    labels = {
      name = "traefik"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install Traefik via Helm
#
# Traefik acts as the Gateway API controller. It registers itself as the
# controller for the "traefik" GatewayClass and exposes itself via a Service
# of type LoadBalancer — AWS cloud-controller-manager provisions the NLB
# automatically. No AWS Load Balancer Controller or IRSA role needed.
#
# Key decisions:
#   providers.kubernetesGateway.enabled     — enables the Gateway API provider
#     (this is under providers, NOT experimental)
#   providers.kubernetesIngress.enabled     — disabled; Gateway API only
#   gateway.enabled                         — let Traefik auto-create the
#                                             GatewayClass and a default Gateway
#                                             in the traefik namespace
#   gateway.listeners.web.port              — map to the web entrypoint (8000)
#   gateway.listeners.web.namespacePolicy   — allow routes from all namespaces
#   service.annotations                     — request an internet-facing NLB
#     "nlb" is the correct value for the in-tree AWS cloud-controller-manager
#     (distinct from the AWS LBC which uses "external")
################################################################################
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = kubernetes_namespace_v1.traefik.metadata[0].name
  version          = "33.2.1"
  create_namespace = false

  values = [
    yamlencode({
      providers = {
        # Enable the Gateway API provider (correct key: providers.kubernetesGateway)
        kubernetesGateway = {
          enabled = true
        }
        # Disable Ingress provider — we use Gateway API only
        kubernetesIngress = {
          enabled = false
        }
      }

      # Expose Traefik via an AWS NLB (internet-facing)
      # "nlb" is the correct value for the in-tree Kubernetes cloud-controller-manager on EKS.
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
      }

      # Traefik auto-creates a GatewayClass and a default Gateway in its own namespace.
      # We configure the Gateway's web listener to:
      #   - listen on the web entrypoint port (8000 internally, exposed as 80 on the NLB)
      #   - accept HTTPRoutes from all namespaces
      gateway = {
        enabled = true
        name    = "traefik"
        # Deploy the auto-created Gateway into gateway-system namespace
        # so it co-locates with our app-gateway.yaml manifest
        namespace = kubernetes_namespace_v1.traefik.metadata[0].name
        listeners = {
          web = {
            port            = 8000
            protocol        = "HTTP"
            hostname        = var.domain_name == "" ? "" : "*.${var.domain_name}"
            namespacePolicy = "All"
          }
        }
      }

      gatewayClass = {
        enabled = true
        name    = "traefik"
      }

      # Entrypoints
      ports = {
        web = {
          port     = 8000
          protocol = "TCP"
          expose = {
            default = true
          }
          # Map NLB port 80 → container port 8000
          exposedPort = 80
        }
        websecure = {
          port     = 8443
          protocol = "TCP"
          expose = {
            default = false
          }
        }
        # Keep dashboard internal only — never expose on the public NLB
        traefik = {
          expose = {
            default = false
          }
        }
      }

      # Basic resource limits for t3.medium nodes
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
      }

      # Two replicas for HA across the two worker nodes
      deployment = {
        replicas = 2
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.traefik,
    null_resource.gateway_api_crds
  ]
}
