# InferaDB AWS Multi-Region - Outputs
# ====================================

# =============================================================================
# VPC Outputs
# =============================================================================

output "primary_vpc_id" {
  description = "VPC ID in primary region"
  value       = module.vpc_primary.vpc_id
}

output "dr_vpc_id" {
  description = "VPC ID in DR region"
  value       = module.vpc_dr.vpc_id
}

# =============================================================================
# EKS Outputs
# =============================================================================

output "primary_cluster_name" {
  description = "EKS cluster name in primary region"
  value       = module.eks_primary.cluster_name
}

output "primary_cluster_endpoint" {
  description = "EKS cluster endpoint in primary region"
  value       = module.eks_primary.cluster_endpoint
}

output "dr_cluster_name" {
  description = "EKS cluster name in DR region"
  value       = module.eks_dr.cluster_name
}

output "dr_cluster_endpoint" {
  description = "EKS cluster endpoint in DR region"
  value       = module.eks_dr.cluster_endpoint
}

# =============================================================================
# InferaDB Outputs
# =============================================================================

output "inferadb_regions" {
  description = "Deployed InferaDB regions"
  value       = module.inferadb.regions
}

output "inferadb_primary_region" {
  description = "Primary region configuration"
  value       = module.inferadb.primary_region
}

output "fdb_clusters" {
  description = "FDB cluster details per region"
  value       = module.inferadb.fdb_clusters
}

output "engine_endpoints" {
  description = "InferaDB Engine endpoints per region"
  value       = module.inferadb.engine_endpoints
}

output "fearless_dr_config" {
  description = "Fearless DR configuration"
  value       = module.inferadb.fearless_dr_config
}

# =============================================================================
# Connection Information
# =============================================================================

output "connection_info" {
  description = "Connection information for applications"
  value       = module.inferadb.cluster_connection_info
}

output "kubeconfig_commands" {
  description = "Commands to configure kubectl"
  value = {
    primary = "aws eks update-kubeconfig --name ${module.eks_primary.cluster_name} --region ${var.primary_region}"
    dr      = "aws eks update-kubeconfig --name ${module.eks_dr.cluster_name} --region ${var.dr_region}"
  }
}

# =============================================================================
# Monitoring
# =============================================================================

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = module.inferadb.monitoring_enabled
}

output "tailscale_acl_rules_count" {
  description = "Number of Tailscale ACL rules"
  value       = module.tailscale_acls.acl_rules_count
}
