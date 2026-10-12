# Kubernetes Gateway API on Amazon EKS with Traefik — A Complete Guide

---

## Introduction

If you've been running Kubernetes workloads in production, you've almost certainly used an Ingress controller — probably nginx. It's been the de facto standard for routing external HTTP traffic into a cluster for years. But that era is coming to an end.

The nginx Ingress controller has announced **end of active support**, and the Kubernetes community has responded with a better answer: the **Gateway API**. In this post we'll walk through what Gateway API is, why it matters, how different controllers implement it, and how to deploy a real Node.js application on Amazon EKS using **Traefik** as the Gateway controller — all provisioned with Terraform.

---

## What Is the Kubernetes Gateway API?

The [Gateway API](https://gateway-api.sigs.k8s.io/) is a collection of official Kubernetes CRDs (Custom Resource Definitions) designed to replace the `Ingress` resource. It graduated to **GA (v1.0)** in October 2023 and has been steadily growing in adoption since.

Where `Ingress` is a single flat resource with limited expressiveness, Gateway API introduces a layered model with clear separation of concerns:

| Resource | Owned by | Purpose |
|---|---|---|
| `GatewayClass` | Cluster operator | Defines which controller manages Gateways |
| `Gateway` | Cluster operator | Configures the actual listener (port, protocol, TLS) |
| `HTTPRoute` | Application team | Defines routing rules to backend Services |
| `TCPRoute`, `TLSRoute`, `GRPCRoute` | Application team | Protocol-specific routing |

This separation matters in real organizations. Platform teams control the `Gateway` (and therefore what load balancer gets provisioned), while application teams deploy `HTTPRoutes` into their own namespaces without needing cluster-wide permissions. That's something the old `Ingress` spec could never cleanly express.

### Why Move Away from nginx Ingress?

The [Ingress-nginx](https://github.com/kubernetes/ingress-nginx) project — the community-maintained nginx Ingress controller — announced it is entering **maintenance-only mode**. New features will not be added, and the recommendation from the Kubernetes SIG-Network team is to migrate to Gateway API. The writing has been on the wall for a while: Ingress is a frozen API spec, and the ecosystem has moved on.

If you're starting a new project today, Gateway API is the right choice. If you have existing Ingress resources, now is the time to plan the migration.

---

## How Gateway API Controllers Work

Gateway API itself is just a specification — a set of CRDs. The actual work of provisioning load balancers and routing traffic is done by a **Gateway controller**. Any controller can implement the spec; they just need to watch for `GatewayClass` resources that advertise their `controllerName`.

Some popular implementations:

| Controller | `controllerName` | Notes |
|---|---|---|
| **Traefik** | `traefik.io/gateway-controller` | Cloud-native, fast, excellent DX |
| **Envoy Gateway** | `gateway.envoyproxy.io/gatewayclass-controller` | CNCF project, powerful |
| **Istio** | `istio.io/gateway-controller` | Service mesh with Gateway API |
| **Cilium** | `io.cilium/gateway-controller` | eBPF-based, very high performance |
| **AWS LBC** | `eks.amazonaws.com/load-balancer-controller` | AWS-native NLB/ALB provisioning |
| **nginx** | `k8s.nginx.org/nginxgateway` | NGINX Gateway Fabric (new project) |

The key insight: **the controller is pluggable**. Your `HTTPRoute` and `Gateway` manifests stay the same regardless of which controller you choose. You only change the `GatewayClass`.

### Why Traefik?

For this walkthrough we chose Traefik because:

- It's battle-tested in production and has first-class Gateway API support
- It installs via a single Helm chart with no IAM roles or AWS-specific setup
- It creates its own `Service` of type `LoadBalancer`, letting the AWS cloud-controller-manager provision the NLB automatically — no AWS Load Balancer Controller needed
- The Traefik dashboard gives you live routing visibility out of the box

---

## Architecture

Here's what we're building:

```
Internet
    │
    ▼
Route53 A-alias (app.chinmayto.com)
    │
    ▼
AWS Network Load Balancer          ← provisioned automatically by EKS
    │                                 when Traefik Service type=LoadBalancer
    ▼
Traefik Pod (Deployment, 2 replicas, namespace: traefik)
    │   GatewayClass: traefik
    │   Gateway: app-gateway (namespace: gateway-system)
    ▼
HTTPRoute (namespace: simple-nodejs-app)
    │   hostname: app.chinmayto.com
    │   path: /
    ▼
ClusterIP Service → Node.js Pod (port 8080)
```

**Infrastructure components (all Terraform-managed):**

- **VPC** — two public + two private subnets across two AZs, single NAT gateway
- **EKS cluster** — managed node group, `t3.medium`, AL2023, Kubernetes 1.36
- **EKS Addons** — `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`
- **Gateway API CRDs** — installed via `kubectl apply` from the official v1.2.0 release
- **Traefik** — installed via Helm chart v33.x, Gateway API provider enabled
- **Route53 A record** — Terraform reads the NLB hostname from the Traefik Service and creates the alias record automatically

**No AWS Load Balancer Controller. No IRSA. No separate IAM policy.** Traefik handles the gateway layer; AWS cloud-controller-manager handles the NLB provisioning.

### File Structure

```
terraform-aws-eks-gateway-api/
├── infrastructure/
│   ├── providers.tf          # AWS, Kubernetes, Helm, Time providers
│   ├── variables.tf          # Region, cluster name, domain, subnets
│   ├── main.tf               # VPC + EKS modules, Route53 data source
│   ├── gateway-api.tf        # Gateway API CRDs + Traefik Helm release
│   ├── app-dns.tf            # data.kubernetes_service_v1 + aws_route53_record
│   └── outputs.tf            # Cluster endpoint, VPC, DNS info
├── k8s-manifests/
│   ├── deploy-simple-nodejs-app.yaml
│   └── gateway-api-nodejs-app.yaml  # HTTPRoute → Traefik Gateway
└── README.md
```

---

## Step-by-Step Deployment

### Prerequisites

- AWS CLI configured with permissions to create EKS, VPC, IAM, Route53 resources
- Terraform >= 1.9
- `kubectl` installed
- A domain registered in Route53 (this guide uses `chinmayto.com`)

### 1. Clone and Initialize

```bash
git clone https://github.com/chinmayto/terraform-aws-eks-gateway-api
cd terraform-aws-eks-gateway-api/infrastructure
terraform init
```

### 2. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

This single `apply` does everything:
- Creates the VPC, subnets, NAT gateway
- Provisions the EKS cluster and node group
- Installs EKS addons
- Installs Gateway API CRDs (v1.2.0)
- Installs Traefik via Helm (with `enableGatewayAPI: true`)
- Waits 90 seconds for the NLB to be provisioned by AWS
- Reads the NLB hostname from the Traefik Service
- Creates the Route53 A-alias record

At the end of apply you'll see:

```
Outputs:

nodejs_app_dns_info = {
  "app_url"        = "http://app.chinmayto.com"
  "full_hostname"  = "app.chinmayto.com"
  "hosted_zone_id" = "Z0XXXXXXXXXXXXXXXXX"
  "nlb_hostname"   = "xxxx.elb.us-east-1.amazonaws.com"
  "subdomain"      = "app"
  "domain_name"    = "chinmayto.com"
}
```

### 3. Deploy Kubernetes Manifests

```bash
# Update kubeconfig (Terraform does this automatically, but run it if needed)
aws eks --region us-east-1 update-kubeconfig --name CT-EKS-Cluster

# Deploy the Node.js application and HTTPRoute
kubectl apply -f k8s-manifests/deploy-simple-nodejs-app.yaml
kubectl apply -f k8s-manifests/gateway-api-nodejs-app.yaml
```

### 4. Verify

```bash
# Traefik pod running?
kubectl get pods -n traefik

# GatewayClass accepted?
kubectl get gatewayclass traefik

# Gateway ready?
kubectl get gateway app-gateway -n gateway-system

# HTTPRoute accepted?
kubectl get httproute -n simple-nodejs-app

# Application responding?
curl http://app.chinmayto.com
```

### Key Terraform Resources

**Traefik Helm release (`gateway-api.tf`)**

```hcl
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name
  version    = "33.2.1"

  values = [yamlencode({
    providers = {
      kubernetesGateway = { enabled = true }
      kubernetesIngress = { enabled = false }
    }
    service = {
      type = "LoadBalancer"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
      }
    }
    gateway = {
      enabled = true
      name    = "traefik"
    }
  })]
}
```

**Route53 record from Traefik Service (`app-dns.tf`)**

```hcl
resource "time_sleep" "wait_for_nlb" {
  create_duration = "90s"
  depends_on      = [helm_release.traefik]
}

data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }
  depends_on = [time_sleep.wait_for_nlb]
}

resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.nlb_hosted_zone_id
    evaluate_target_health = true
  }
}
```

**Gateway manifest (`app-gateway.yaml`)**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: gateway-system
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      hostname: "app.chinmayto.com"
      allowedRoutes:
        namespaces:
          from: All
```

**HTTPRoute manifest (`gateway-api-nodejs-app.yaml`)**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: simple-nodejs-httproute
  namespace: simple-nodejs-app
spec:
  parentRefs:
    - name: app-gateway
      namespace: gateway-system
  hostnames:
    - "app.chinmayto.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: service-nodejs-app
          port: 80
```

---

## Cleanup

To tear everything down cleanly — delete the Kubernetes resources first so the NLB is deprovisioned before Terraform tries to destroy the VPC.

```bash
# 1. Delete Kubernetes resources (this deprovisions the NLB)
kubectl delete -f k8s-manifests/gateway-api-nodejs-app.yaml
kubectl delete -f k8s-manifests/deploy-simple-nodejs-app.yaml

# 2. Wait ~60 seconds for the NLB to be fully removed by AWS
sleep 60

# 3. Destroy all Terraform-managed infrastructure
cd infrastructure
terraform destroy
```

> **Why the order matters**: If you run `terraform destroy` while the Traefik LoadBalancer Service still exists, AWS will not delete the NLB (it's owned by Kubernetes). The NLB's ENIs will still be attached to the VPC subnets, and Terraform will fail trying to delete the VPC with a dependency error. Always drain the k8s resources first.

---

## Conclusion

The Kubernetes Gateway API is a genuine step forward from the Ingress spec. The separation between `GatewayClass`, `Gateway`, and `HTTPRoute` maps cleanly onto how real platform and application teams work. The nginx Ingress controller served us well for years, but with active development winding down and Gateway API reaching GA, now is the right time to migrate.

Traefik makes this particularly straightforward on EKS — no IAM roles, no IRSA, no separate controller installation just to provision a load balancer. One Helm chart, one `helm_release` resource in Terraform, and you have a production-ready Gateway API implementation with an NLB and Route53 DNS fully automated.

The full deployment — VPC, EKS, Traefik, NLB, Route53 — is a single `terraform apply`. That's the kind of operational simplicity that makes a difference at scale.

---

## References

- **GitHub Repository**: [chinmayto/terraform-aws-eks-gateway-api](https://github.com/chinmayto/terraform-aws-eks-gateway-api)
- [Kubernetes Gateway API — Official Docs](https://gateway-api.sigs.k8s.io/)
- [Gateway API — Supported Features by Implementation](https://gateway-api.sigs.k8s.io/implementations/)
- [Traefik Gateway API Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-gateway/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [Amazon EKS — Gateway API](https://docs.aws.amazon.com/eks/latest/userguide/gateway-api.html)
