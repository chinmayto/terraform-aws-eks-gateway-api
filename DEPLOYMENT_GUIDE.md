# Complete Deployment Guide

## Overview

This guide walks you through deploying an EKS cluster with Gateway API using AWS Load Balancer Controller.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- Terraform installed
- Domain registered in Route53

## Step-by-Step Deployment

### 1. Deploy Infrastructure

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

This will create:
- EKS cluster with required addons
- VPC with properly tagged subnets
- AWS Load Balancer Controller with IAM permissions
- Gateway API CRDs

### 2. Verify EKS Cluster

```bash
# Update kubeconfig (should be done automatically by Terraform)
aws eks --region us-east-1 update-kubeconfig --name CT-EKS-Cluster

# Verify cluster is ready
kubectl get nodes

# Verify AWS Load Balancer Controller is running
kubectl get pods -n aws-load-balancer-system
```

### 3. Deploy Gateway API Resources

```bash
# Deploy in order
kubectl apply -f k8s-manifests/gateway-system-namespace.yaml
kubectl apply -f k8s-manifests/gateway-class.yaml
kubectl apply -f k8s-manifests/app-gateway.yaml

# Verify Gateway is created
kubectl get gateway -n gateway-system
```

### 4. Wait for Gateway LoadBalancer

```bash
# Wait for Gateway to get an address (this may take 2-5 minutes)
kubectl get gateway app-gateway -n gateway-system -w

# Check Gateway status
kubectl describe gateway app-gateway -n gateway-system
```

### 5. Deploy Application

```bash
# Deploy the Node.js application
kubectl apply -f k8s-manifests/deploy-simple-nodejs-app.yaml

# Deploy the HTTPRoute
kubectl apply -f k8s-manifests/gateway-api-nodejs-app.yaml

# Verify application is running
kubectl get pods -n simple-nodejs-app
kubectl get httproute -n simple-nodejs-app
```

### 6. Configure DNS

```bash
# Make the script executable
chmod +x scripts/configure-dns.sh

# Run the DNS configuration script
./scripts/configure-dns.sh
```

### 7. Verify Deployment

```bash
# Check Gateway status
kubectl get gateway app-gateway -n gateway-system

# Check HTTPRoute status
kubectl get httproute simple-nodejs-httproute -n simple-nodejs-app

# Test the application (wait a few minutes for DNS propagation)
curl http://app.chinmayto.com
```

## Manual DNS Configuration (Alternative)

If you prefer to configure DNS manually:

1. Get the Gateway LoadBalancer hostname:
   ```bash
   kubectl get gateway app-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'
   ```

2. Create Route53 record:
   - Type: A (Alias)
   - Name: app.chinmayto.com
   - Alias Target: [Gateway LoadBalancer hostname]
   - Zone ID: Z26RNL4JYFTOTI (for us-east-1 NLB)

## Troubleshooting

### Gateway Not Getting Address

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n aws-load-balancer-system deployment/aws-load-balancer-controller

# Check Gateway events
kubectl describe gateway app-gateway -n gateway-system
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute simple-nodejs-httproute -n simple-nodejs-app

# Verify service exists
kubectl get svc -n simple-nodejs-app
```

### DNS Issues

```bash
# Check Route53 record
aws route53 list-resource-record-sets --hosted-zone-id [YOUR_ZONE_ID]

# Test DNS resolution
nslookup app.chinmayto.com
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s-manifests/

# Delete infrastructure
cd infrastructure
terraform destroy
```

## Important Notes

1. **Subnet Tags**: Ensure public subnets have `kubernetes.io/role/elb = "1"` tag
2. **IAM Permissions**: AWS Load Balancer Controller needs proper IAM permissions
3. **Gateway API Version**: Using Gateway API v1.2.0
4. **DNS Propagation**: Allow 5-10 minutes for DNS changes to propagate
5. **LoadBalancer Provisioning**: Gateway LoadBalancer creation takes 2-5 minutes