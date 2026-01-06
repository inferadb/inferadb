# FDB Cluster Module - Outputs
# ============================
# Output values for use by other modules

output "cluster_name" {
  description = "Name of the FDB cluster"
  value       = var.cluster_name
}

output "namespace" {
  description = "Namespace where the FDB cluster is deployed"
  value       = var.namespace
}

output "fdb_version" {
  description = "FoundationDB version"
  value       = var.fdb_version
}

output "cluster_file_secret_name" {
  description = "Name of the secret containing the FDB cluster file"
  value       = local.cluster_file_secret
}

output "cluster_file_configmap_name" {
  description = "Name of the ConfigMap containing the FDB cluster file"
  value       = kubernetes_config_map.cluster_file.metadata[0].name
}

output "connection_string_path" {
  description = "Path to mount the cluster file in application pods"
  value       = "/etc/foundationdb/fdb.cluster"
}

output "region_id" {
  description = "Region identifier for this cluster"
  value       = var.region_id
}

output "datacenter_id" {
  description = "Datacenter identifier for this cluster"
  value       = var.datacenter_id != "" ? var.datacenter_id : var.region_id
}

output "is_primary" {
  description = "Whether this is the primary region"
  value       = var.is_primary
}

output "priority" {
  description = "Region priority"
  value       = var.priority
}

output "redundancy_mode" {
  description = "FDB redundancy mode"
  value       = var.redundancy_mode
}

output "storage_engine" {
  description = "FDB storage engine"
  value       = var.storage_engine
}

output "process_counts" {
  description = "Number of processes per role"
  value       = var.process_counts
}

output "tailscale_enabled" {
  description = "Whether Tailscale sidecar is enabled"
  value       = var.tailscale.enabled
}

output "multi_region_enabled" {
  description = "Whether multi-region configuration is enabled"
  value       = var.multi_region_config.enabled
}

output "labels" {
  description = "Labels applied to the cluster resources"
  value       = local.common_labels
}

# Volume mount spec for applications that need to connect to this cluster
output "volume_mount_spec" {
  description = "Volume mount specification for applications to use the cluster file"
  value = {
    volume = {
      name = "fdb-cluster-file"
      configMap = {
        name = kubernetes_config_map.cluster_file.metadata[0].name
        items = [
          {
            key  = "fdb.cluster"
            path = "fdb.cluster"
          }
        ]
      }
    }
    volumeMount = {
      name      = "fdb-cluster-file"
      mountPath = "/etc/foundationdb"
      readOnly  = true
    }
  }
}

# Environment variable spec for applications
output "env_var_spec" {
  description = "Environment variable specification for FDB cluster file path"
  value = {
    name  = "INFERADB__FOUNDATIONDB__CLUSTER_FILE"
    value = "/etc/foundationdb/fdb.cluster"
  }
}
