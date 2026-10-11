####################################################################################
# Data source for availability zones
####################################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

####################################################################################
### Route53 Hosted Zone
####################################################################################
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

####################################################################################
### VPC Module Configuration
### terraform-aws-modules/vpc/aws ~> 6.0
### No input variable renames in v6 — only requires AWS provider v6.
####################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-VPC"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Name      = "${var.cluster_name}-VPC"
    Terraform = "true"
  }
}

####################################################################################
### EKS Cluster Module Configuration
### terraform-aws-modules/eks/aws ~> 21.0
###
### Breaking renames from v20 → v21 applied here:
###   cluster_name                     → name
###   cluster_version                  → kubernetes_version
###   cluster_endpoint_public_access   → endpoint_public_access
###   cluster_addons                   → addons
###
### Behaviour changes in v21 (no action needed for a new cluster):
###   addons.most_recent               now defaults to true  (explicit below for clarity)
###   addons.resolve_conflicts_on_create now defaults to "NONE"
###   ami_type                         now defaults to AL2023_x86_64_STANDARD
###   enable_monitoring                now defaults to false
####################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    kube-proxy = {
      most_recent    = true
      before_compute = true
    }
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    EKS_Node_Group = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      ami_type = "AL2023_x86_64_STANDARD"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      subnet_ids = module.vpc.private_subnets
    }
  }

  tags = {
    Name      = var.cluster_name
    Terraform = "true"
  }
}

####################################################################################
### Null Resource to update the kubeconfig file
####################################################################################
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
  }

  depends_on = [module.eks]
}
