# InferaDB GCP Multi-Region - Outputs
# ====================================

# =============================================================================
# GKE Cluster Outputs
# =============================================================================

output "gke_primary_name" {
  description = "Name of the primary GKE cluster"
  value       = module.gke_primary.name
}

output "gke_primary_endpoint" {
  description = "Endpoint of the primary GKE cluster"
  value       = module.gke_primary.endpoint
  sensitive   = true
}

output "gke_dr_name" {
  description = "Name of the DR GKE cluster"
  value       = module.gke_dr.name
}

output "gke_dr_endpoint" {
  description = "Endpoint of the DR GKE cluster"
  value       = module.gke_dr.endpoint
  sensitive   = true
}

# =============================================================================
# Kubectl Configuration
# =============================================================================

output "kubectl_config_primary" {
  description = "kubectl configuration command for primary cluster"
  value       = "gcloud container clusters get-credentials ${module.gke_primary.name} --region ${var.primary_region} --project ${var.project_id}"
}

output "kubectl_config_dr" {
  description = "kubectl configuration command for DR cluster"
  value       = "gcloud container clusters get-credentials ${module.gke_dr.name} --region ${var.dr_region} --project ${var.project_id}"
}

# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_primary_name" {
  description = "Name of the primary VPC"
  value       = module.vpc_primary.network_name
}

output "vpc_dr_name" {
  description = "Name of the DR VPC"
  value       = module.vpc_dr.network_name
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
  description = "Connection information for InferaDB"
  value = {
    primary = {
      region = var.primary_region
      gke    = module.gke_primary.name
      engine = "inferadb-engine.${var.namespace}.svc.cluster.local:8080"
      fdb    = "inferadb-fdb.${var.namespace}.svc.cluster.local:4500"
    }
    dr = {
      region = var.dr_region
      gke    = module.gke_dr.name
      engine = "inferadb-engine.${var.namespace}.svc.cluster.local:8080"
      fdb    = "inferadb-fdb.${var.namespace}.svc.cluster.local:4500"
    }
    tailscale = {
      tailnet = var.tailscale_tailnet
    }
  }
}
