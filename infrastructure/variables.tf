variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "CT-EKS-Cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster. Passed to the EKS module as `kubernetes_version`."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

####################################################################################
### DNS Variables
####################################################################################
variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = "chinmayto.com"
}

variable "app_subdomain" {
  description = "Subdomain for Node.js application (path-based routing / URL rewriting)"
  type        = string
  default     = "app"
}

variable "app1_subdomain" {
  description = "Subdomain for Node.js application 1 (hostname-based routing)"
  type        = string
  default     = "app1"
}

variable "app2_subdomain" {
  description = "Subdomain for Node.js application 2 (hostname-based routing)"
  type        = string
  default     = "app2"
}
