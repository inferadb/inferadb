# InferaDB Multi-Cloud - Outputs
# ===============================

# =============================================================================
# AWS Outputs
# =============================================================================

output "aws_eks_name" {
  description = "Name of the AWS EKS cluster"
  value       = module.eks.cluster_name
}

output "aws_eks_endpoint" {
  description = "Endpoint of the AWS EKS cluster"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "aws_vpc_id" {
  description = "ID of the AWS VPC"
  value       = module.vpc_aws.vpc_id
}

output "aws_kubectl_config" {
  description = "kubectl configuration command for AWS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# =============================================================================
# GCP Outputs
# =============================================================================

output "gcp_gke_name" {
  description = "Name of the GCP GKE cluster"
  value       = module.gke.name
}

output "gcp_gke_endpoint" {
  description = "Endpoint of the GCP GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "gcp_vpc_name" {
  description = "Name of the GCP VPC"
  value       = module.vpc_gcp.network_name
}

output "gcp_kubectl_config" {
  description = "kubectl configuration command for GCP cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.gcp_region} --project ${var.gcp_project_id}"
}

# =============================================================================
# InferaDB Outputs
# =============================================================================

output "inferadb_regions" {
  description = "InferaDB deployment regions"
  value       = module.inferadb.regions
}

output "inferadb_fdb_clusters" {
  description = "FDB cluster information"
  value       = module.inferadb.fdb_clusters
}

output "inferadb_engine_endpoints" {
  description = "InferaDB Engine endpoints"
  value       = module.inferadb.engine_endpoints
}

# =============================================================================
# Connection Information
# =============================================================================

output "connection_info" {
  description = "Connection information for InferaDB multi-cloud deployment"
  value = {
    aws_primary = {
      cloud   = "AWS"
      region  = var.aws_region
      cluster = module.eks.cluster_name
      engine  = "inferadb-engine.${var.namespace}.svc.cluster.local:8080"
      fdb     = "inferadb-fdb.${var.namespace}.svc.cluster.local:4500"
    }
    gcp_dr = {
      cloud   = "GCP"
      region  = var.gcp_region
      project = var.gcp_project_id
      cluster = module.gke.name
      engine  = "inferadb-engine.${var.namespace}.svc.cluster.local:8080"
      fdb     = "inferadb-fdb.${var.namespace}.svc.cluster.local:4500"
    }
    tailscale = {
      tailnet = var.tailscale_tailnet
    }
  }
}

# =============================================================================
# Summary
# =============================================================================

output "deployment_summary" {
  description = "Summary of the multi-cloud deployment"
  value       = <<-EOT

    InferaDB Multi-Cloud Deployment Summary
    =======================================

    AWS (Primary):
      Region:  ${var.aws_region}
      Cluster: ${module.eks.cluster_name}
      kubectl: aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}

    GCP (DR):
      Region:  ${var.gcp_region}
      Project: ${var.gcp_project_id}
      Cluster: ${module.gke.name}
      kubectl: gcloud container clusters get-credentials ${module.gke.name} --region ${var.gcp_region} --project ${var.gcp_project_id}

    Tailscale:
      Tailnet: ${var.tailscale_tailnet}

    Verify deployment:
      kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=inferadb-engine

  EOT
}
