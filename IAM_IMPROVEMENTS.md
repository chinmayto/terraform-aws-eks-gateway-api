# AWS Load Balancer Controller IAM Improvements

## What Was Changed

### Before (Custom IAM Policy)
- **Large inline policy**: 200+ lines of hardcoded IAM permissions
- **Maintenance burden**: Manual updates needed when AWS changes requirements
- **Error-prone**: Risk of missing permissions or having outdated policies
- **Version drift**: Policy might not match the controller version

### After (Official AWS Policy)
- **Dynamic policy fetch**: Uses `data "http"` to fetch the official AWS policy
- **Always up-to-date**: Policy matches the exact controller version (v2.8.1)
- **AWS maintained**: Official policy maintained by AWS Load Balancer Controller team
- **Reduced maintenance**: No need to manually update permissions

## Current Implementation

```hcl
# Fetch official policy from AWS Load Balancer Controller repository
data "http" "aws_load_balancer_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json"
  
  request_headers = {
    Accept = "application/json"
  }
}

# Create IAM policy using the fetched content
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.aws_load_balancer_controller_policy.response_body
}
```

## Benefits

1. **Accuracy**: Always uses the correct permissions for the specific controller version
2. **Security**: No over-permissioning or under-permissioning issues
3. **Maintainability**: Automatic updates when changing controller versions
4. **Reliability**: Reduces deployment failures due to permission issues
5. **Best Practice**: Follows AWS recommended approach

## Alternative Approaches Considered

### 1. EKS Managed Add-on
- **Pros**: Fully managed by AWS, automatic updates
- **Cons**: Limited customization, may not support all features
- **Status**: Not yet available for AWS Load Balancer Controller

### 2. EKS Blueprints Add-on Module
- **Pros**: Simplified configuration, built-in best practices
- **Cons**: Additional dependency, less control over configuration
- **Status**: Could be implemented in future iterations

### 3. AWS Managed IAM Policy
- **Pros**: No need to create custom policy
- **Cons**: AWS doesn't provide a managed policy for this controller
- **Status**: Not available from AWS

## Verification Commands

After deployment, verify the IAM configuration:

```bash
# Check if the role exists
aws iam get-role --role-name CT-EKS-Cluster-aws-load-balancer-controller

# Check policy attachment
aws iam list-attached-role-policies --role-name CT-EKS-Cluster-aws-load-balancer-controller

# Verify controller is running
kubectl get pods -n aws-load-balancer-system

# Check service account annotation
kubectl describe serviceaccount aws-load-balancer-controller -n aws-load-balancer-system
```

## Future Improvements

1. **Version Management**: Consider using variables for controller version
2. **Policy Validation**: Add validation to ensure policy is valid JSON
3. **Backup Policy**: Implement fallback to local policy file if HTTP fetch fails
4. **Monitoring**: Add CloudWatch alarms for controller health