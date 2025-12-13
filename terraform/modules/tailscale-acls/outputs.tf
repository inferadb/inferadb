# Tailscale ACLs Module - Outputs
# ================================

output "acl_policy" {
  description = "The generated ACL policy document"
  value       = local.acl_policy
  sensitive   = false
}

output "acl_policy_json" {
  description = "The ACL policy as a JSON string"
  value       = jsonencode(local.acl_policy)
}

output "tags" {
  description = "Tag definitions used in the ACL policy"
  value = {
    fdb     = local.fdb_tag
    engine  = local.engine_tag
    control = local.control_tag
  }
}

output "ports" {
  description = "Port configuration used in the ACL policy"
  value = {
    fdb_port          = local.fdb_port
    fdb_tls_port      = local.fdb_tls_port
    engine_http_port  = local.engine_http_port
    engine_grpc_port  = local.engine_grpc_port
    engine_mesh_port  = local.engine_mesh_port
    control_http_port = local.control_http_port
    control_mesh_port = local.control_mesh_port
  }
}

output "acl_rules_count" {
  description = "Number of ACL rules in the policy"
  value       = length(local.all_acls)
}

output "tag_owners" {
  description = "Tag ownership configuration"
  value       = local.tag_owners
}

output "ssh_enabled" {
  description = "Whether SSH access is enabled"
  value       = var.enable_ssh
}
