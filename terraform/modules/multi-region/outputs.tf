# Multi-Region Orchestration Module - Outputs
# ============================================
# Output values for the multi-region deployment

output "regions" {
  description = "Deployed regions with their configuration"
  value = {
    for r in var.regions : r.id => {
      id         = r.id
      name       = r.name
      is_primary = r.is_primary
      priority   = r.priority
      namespace  = r.namespace
    }
  }
}

output "primary_region" {
  description = "The primary region configuration"
  value = {
    id        = local.primary_region.id
    name      = local.primary_region.name
    namespace = local.primary_region.namespace
  }
}

output "fdb_operators" {
  description = "FDB Operator deployment status per region"
  value = {
    for region_id, op in module.fdb_operator : region_id => {
      namespace       = op.namespace
      release_name    = op.release_name
      release_version = op.release_version
      release_status  = op.release_status
      operator_ready  = op.operator_ready
    }
  }
}

output "fdb_clusters" {
  description = "FDB cluster details per region"
  value = {
    for region_id, cluster in module.fdb_cluster : region_id => {
      cluster_name                = cluster.cluster_name
      namespace                   = cluster.namespace
      fdb_version                 = cluster.fdb_version
      region_id                   = cluster.region_id
      is_primary                  = cluster.is_primary
      redundancy_mode             = cluster.redundancy_mode
      cluster_file_secret_name    = cluster.cluster_file_secret_name
      cluster_file_configmap_name = cluster.cluster_file_configmap_name
      tailscale_enabled           = cluster.tailscale_enabled
    }
  }
}

output "engine_endpoints" {
  description = "InferaDB Engine service endpoints per region"
  value = var.engine.enabled ? {
    for region_id, svc in kubernetes_service.engine : region_id => {
      service_name = svc.metadata[0].name
      namespace    = svc.metadata[0].namespace
      http_port    = 8080
      grpc_port    = 8081
      mesh_port    = 8082
      cluster_ip   = svc.spec[0].cluster_ip
    }
  } : {}
}

output "engine_headless_endpoints" {
  description = "InferaDB Engine headless service endpoints per region"
  value = var.engine.enabled ? {
    for region_id, svc in kubernetes_service.engine_headless : region_id => {
      service_name = svc.metadata[0].name
      namespace    = svc.metadata[0].namespace
      dns_name     = "${svc.metadata[0].name}.${svc.metadata[0].namespace}.svc.cluster.local"
    }
  } : {}
}

output "fearless_dr_config" {
  description = "Fearless DR configuration"
  value = {
    enabled        = var.fearless_dr.enabled
    usable_regions = var.fearless_dr.usable_regions
    satellite_logs = var.fearless_dr.satellite_logs
    regions        = local.fdb_regions
  }
}

output "tailscale_config" {
  description = "Tailscale networking configuration"
  value = {
    enabled     = var.tailscale.enabled
    secret_name = var.tailscale.secret_name
    image       = var.tailscale.image
  }
}

output "cluster_connection_info" {
  description = "Connection information for applications"
  value = {
    for region_id, cluster in module.fdb_cluster : region_id => {
      fdb_cluster_file_path = "/etc/foundationdb/fdb.cluster"
      fdb_configmap_name    = cluster.cluster_file_configmap_name
      engine_service        = var.engine.enabled ? "inferadb-engine.${var.regions[index(var.regions[*].id, region_id)].namespace}.svc.cluster.local" : null
      engine_grpc_port      = 8081
      engine_http_port      = 8080
    }
  }
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.monitoring.enabled
}
