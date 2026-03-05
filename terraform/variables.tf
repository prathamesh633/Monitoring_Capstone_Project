###############################################################################
# General
###############################################################################
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix used for all resource names"
  type        = string
  default     = "capstone"
}

variable "environment" {
  description = "Deployment environment (dev | staging | production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

###############################################################################
# VPC
###############################################################################
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ, used by EKS nodes)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "availability_zones" {
  description = "AZs to use (must match number of subnet CIDR lists)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

###############################################################################
# EKS Cluster
###############################################################################
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "capstone-eks-cluster"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_disk_size" {
  description = "EBS disk size (GiB) for each worker node"
  type        = number
  default     = 20
}

###############################################################################
# Docker / App
###############################################################################
variable "docker_image" {
  description = "Full Docker image reference deployed to the cluster"
  type        = string
  default     = "prathameshbhujade/python-flask-app:latest"
}
