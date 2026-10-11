terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  backend "s3" {
    bucket                     = "chinmayto-terraform-state-bucket-1755526674"
    key                        = "eks-cluster-gateway-api/terraform.tfstate"
    region                     = "us-east-1"
    encrypt                    = true
    use_lockfile               = true
    skip_requesting_account_id = false
  }
}

provider "aws" {
  region = var.aws_region
}

# Kubernetes provider configuration — no syntax changes between v2 and v3
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm provider v3: `kubernetes` is now a nested object attribute (kubernetes = {...})
# instead of a block (kubernetes {...}). The exec sub-object follows the same pattern.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
