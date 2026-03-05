variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate (base64-encoded)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

output "cluster_endpoint" {
  value = var.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = var.cluster_certificate_authority_data
}

output "cluster_name" {
  value = var.cluster_name
}
