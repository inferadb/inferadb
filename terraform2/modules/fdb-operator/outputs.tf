# FDB Kubernetes Operator - Outputs
# ==================================
# Output values for use by other modules

output "namespace" {
  description = "Namespace where the FDB operator is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.fdb_operator.name
}

output "release_version" {
  description = "Installed operator version"
  value       = helm_release.fdb_operator.version
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.fdb_operator.status
}

output "service_account_name" {
  description = "Name of the operator service account"
  value       = var.service_account_name
}

output "multi_cluster_mode" {
  description = "Whether multi-cluster mode is enabled"
  value       = var.multi_cluster_mode
}

output "cluster_label" {
  description = "Cluster label for multi-cluster mode"
  value       = var.cluster_label
}

output "metrics_enabled" {
  description = "Whether metrics are enabled"
  value       = var.enable_metrics
}

output "metrics_port" {
  description = "Prometheus metrics port"
  value       = var.enable_metrics ? var.metrics_port : null
}

output "fdb_version" {
  description = "Default FoundationDB version"
  value       = var.fdb_version
}

output "operator_ready" {
  description = "Indicates the operator is deployed and ready"
  value       = helm_release.fdb_operator.status == "deployed"
}
