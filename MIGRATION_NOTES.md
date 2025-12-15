# Migration from nginx ingress to Gateway API

## Summary of Changes

### Removed Components
- ArgoCD (complete removal including terraform configuration)
- nginx ingress controller
- All ArgoCD-related variables and outputs

### Added Components
- AWS Load Balancer Controller with Gateway API support
- Gateway API CRDs installation
- Gateway API resources (GatewayClass, Gateway, HTTPRoute)
- AWS NLB-based LoadBalancer for ingress traffic

### Updated Files

#### Terraform Infrastructure
- `infrastructure/nginx-ingress.tf` → `infrastructure/gateway-api.tf`
- `infrastructure/argocd.tf` → **DELETED**
- `infrastructure/variables.tf` → Removed ArgoCD variables
- `infrastructure/outputs.tf` → Updated for Gateway API
- `infrastructure/app-dns.tf` → Points to Gateway API service

#### Kubernetes Manifests
- `k8s-manifests/nginx-ingress-nodejs-app.yaml` → `k8s-manifests/gateway-api-nodejs-app.yaml`
- Changed from `Ingress` to `HTTPRoute` resource
- Added separate Gateway API manifest files:
  - `k8s-manifests/gateway-system-namespace.yaml`
  - `k8s-manifests/gateway-class.yaml`
  - `k8s-manifests/app-gateway.yaml`

## Deployment Steps

1. **Destroy existing infrastructure** (if needed):
   ```bash
   cd infrastructure
   terraform destroy
   ```

2. **Deploy new infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Gateway API resources**:
   ```bash
   kubectl apply -f k8s-manifests/gateway-system-namespace.yaml
   kubectl apply -f k8s-manifests/gateway-class.yaml
   kubectl apply -f k8s-manifests/app-gateway.yaml
   ```

4. **Wait for AWS Load Balancer Controller** to be ready:
   ```bash
   kubectl get pods -n aws-load-balancer-system
   kubectl get gateway -n gateway-system
   ```

5. **Deploy application**:
   ```bash
   kubectl apply -f k8s-manifests/deploy-simple-nodejs-app.yaml
   kubectl apply -f k8s-manifests/gateway-api-nodejs-app.yaml
   ```

6. **Configure DNS**:
   ```bash
   chmod +x scripts/configure-dns.sh
   ./scripts/configure-dns.sh
   ```

7. **Verify HTTPRoute**:
   ```bash
   kubectl get httproute -n simple-nodejs-app
   kubectl describe httproute simple-nodejs-httproute -n simple-nodejs-app
   ```

## Key Benefits

- **Modern API**: Gateway API is the successor to Ingress
- **Native AWS integration**: AWS Load Balancer Controller provides native AWS features
- **Simplified architecture**: Removed ArgoCD complexity
- **Better performance**: Direct integration with AWS NLB

## Notes

- The application will be accessible at `http://app.chinmayto.com`
- DNS records automatically point to the Gateway API LoadBalancer
- Gateway API provides more flexible routing than traditional Ingress
- Uses AWS Network Load Balancer (NLB) for better performance