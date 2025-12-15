# terraform-aws-eks-gateway-api

This project deploys an EKS cluster on AWS with Gateway API using AWS Load Balancer Controller for ingress traffic management, replacing the previous nginx ingress setup.

## Architecture

- **EKS Cluster**: Managed Kubernetes cluster on AWS
- **Gateway API**: Modern ingress specification using AWS Load Balancer Controller
- **AWS Load Balancer Controller**: Native AWS controller for Gateway API
- **Route53**: DNS management for application routing
- **Simple Node.js App**: Sample application deployed with Gateway API routing

## Key Changes from Previous Version

- **Removed**: nginx ingress controller and ArgoCD
- **Added**: AWS Load Balancer Controller with Gateway API support
- **Updated**: DNS configuration to point to Gateway API LoadBalancer
- **Migrated**: Ingress resources to HTTPRoute resources

## Deployment

1. **Initialize Terraform**:
   ```bash
   cd infrastructure
   terraform init
   ```

2. **Plan and Apply**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Deploy Gateway API Resources**:
   ```bash
   kubectl apply -f k8s-manifests/gateway-system-namespace.yaml
   kubectl apply -f k8s-manifests/gateway-class.yaml
   kubectl apply -f k8s-manifests/app-gateway.yaml
   ```

4. **Deploy Application**:
   ```bash
   kubectl apply -f k8s-manifests/deploy-simple-nodejs-app.yaml
   kubectl apply -f k8s-manifests/gateway-api-nodejs-app.yaml
   ```

5. **Configure DNS** (after Gateway is ready):
   ```bash
   chmod +x scripts/configure-dns.sh
   ./scripts/configure-dns.sh
   ```

## Gateway API Resources

- **GatewayClass**: `aws-load-balancer-controller` - Managed by AWS Load Balancer Controller
- **Gateway**: `app-gateway` - Listens on port 80 for HTTP traffic with NLB
- **HTTPRoute**: Routes traffic from the gateway to the Node.js service

## Access

The application will be available at: `http://app.chinmayto.com`

## Components

- **AWS Load Balancer Controller**: Native AWS controller for managing load balancers
- **Gateway API CRDs**: Kubernetes Gateway API custom resources
- **Network Load Balancer**: AWS NLB created by the Gateway resource