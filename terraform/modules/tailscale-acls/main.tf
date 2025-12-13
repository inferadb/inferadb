# Tailscale ACLs Module - Main
# ============================
# Manages Tailscale ACLs for InferaDB multi-region networking
#
# This module creates ACL policies that:
# - Allow FDB nodes to communicate across regions
# - Allow Engine pods to discover and communicate with each other
# - Restrict access to only authorized services

terraform {
  required_version = ">= 1.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13"
    }
  }
}

locals {
  # Default ports
  fdb_port          = coalesce(var.ports.fdb_port, 4500)
  fdb_tls_port      = coalesce(var.ports.fdb_tls_port, 4501)
  engine_http_port  = coalesce(var.ports.engine_http_port, 8080)
  engine_grpc_port  = coalesce(var.ports.engine_grpc_port, 8081)
  engine_mesh_port  = coalesce(var.ports.engine_mesh_port, 8082)
  control_http_port = coalesce(var.ports.control_http_port, 9091)
  control_mesh_port = coalesce(var.ports.control_mesh_port, 9092)

  # Tags
  fdb_tag     = coalesce(var.tags.fdb_tag, "tag:fdb")
  engine_tag  = coalesce(var.tags.engine_tag, "tag:inferadb-engine")
  control_tag = coalesce(var.tags.control_tag, "tag:inferadb-control")

  # Autogroups
  admin_group = coalesce(var.autogroups.admin_group, "autogroup:admin")

  # Build ACL rules
  base_acls = [
    # FDB nodes can communicate with each other (for Fearless DR)
    {
      action = "accept"
      src    = [local.fdb_tag]
      dst    = ["${local.fdb_tag}:${local.fdb_port}", "${local.fdb_tag}:${local.fdb_tls_port}"]
    },

    # Engine pods can communicate with FDB nodes
    {
      action = "accept"
      src    = [local.engine_tag]
      dst    = ["${local.fdb_tag}:${local.fdb_port}", "${local.fdb_tag}:${local.fdb_tls_port}"]
    },

    # Engine pods can communicate with each other (for replication/mesh)
    {
      action = "accept"
      src    = [local.engine_tag]
      dst = [
        "${local.engine_tag}:${local.engine_grpc_port}",
        "${local.engine_tag}:${local.engine_mesh_port}"
      ]
    },

    # Control pods can communicate with Engine pods
    {
      action = "accept"
      src    = [local.control_tag]
      dst = [
        "${local.engine_tag}:${local.engine_mesh_port}",
        "${local.engine_tag}:${local.engine_http_port}"
      ]
    },

    # Engine pods can communicate with Control pods
    {
      action = "accept"
      src    = [local.engine_tag]
      dst    = ["${local.control_tag}:${local.control_mesh_port}"]
    },

    # Admins can access all InferaDB services
    {
      action = "accept"
      src    = [local.admin_group]
      dst = [
        "${local.fdb_tag}:*",
        "${local.engine_tag}:*",
        "${local.control_tag}:*"
      ]
    }
  ]

  # SSH ACLs (if enabled)
  ssh_acls = var.enable_ssh ? [
    {
      action = "accept"
      src    = var.ssh_allowed_users
      dst    = ["${local.fdb_tag}:22", "${local.engine_tag}:22", "${local.control_tag}:22"]
    }
  ] : []

  # Additional ACLs from variable
  additional_acls = var.additional_acls

  # Combine all ACLs
  all_acls = concat(local.base_acls, local.ssh_acls, local.additional_acls)

  # Build tag owners
  tag_owners = merge(
    length(var.tag_owners.fdb_owners) > 0 ? {
      (local.fdb_tag) = var.tag_owners.fdb_owners
      } : {
      (local.fdb_tag) = [local.admin_group]
    },
    length(var.tag_owners.engine_owners) > 0 ? {
      (local.engine_tag) = var.tag_owners.engine_owners
      } : {
      (local.engine_tag) = [local.admin_group]
    },
    length(var.tag_owners.control_owners) > 0 ? {
      (local.control_tag) = var.tag_owners.control_owners
      } : {
      (local.control_tag) = [local.admin_group]
    }
  )

  # Build ACL policy document
  acl_policy = {
    acls = local.all_acls

    tagOwners = local.tag_owners

    # Node attributes for routing
    nodeAttrs = length(var.regions) > 0 ? [
      for region in var.regions : {
        target = ["${local.fdb_tag}"]
        attr   = ["region:${region.id}"]
      }
    ] : []

    # Auto-approvers for tagged devices
    autoApprovers = {
      routes = {
        "10.0.0.0/8"     = [local.admin_group]
        "172.16.0.0/12"  = [local.admin_group]
        "192.168.0.0/16" = [local.admin_group]
      }
    }

    # SSH configuration
    ssh = var.enable_ssh ? [
      {
        action = "accept"
        src    = var.ssh_allowed_users
        dst    = [local.fdb_tag, local.engine_tag, local.control_tag]
        users  = ["root", "nonroot"]
      }
    ] : []

    # DNS configuration
    dns = var.dns.enable_magic_dns ? {
      nameservers = concat(
        var.dns.nameservers,
        var.dns.enable_magic_dns ? ["100.100.100.100"] : []
      )
      searchPaths      = var.dns.search_paths
      overrideLocalDns = var.dns.override_local_dns
    } : null
  }
}

# Apply ACL policy to Tailscale
resource "tailscale_acl" "inferadb" {
  acl = jsonencode(local.acl_policy)

  lifecycle {
    # Prevent accidental destruction
    prevent_destroy = false
  }
}

# Create DNS records for services (optional)
resource "tailscale_dns_nameservers" "inferadb" {
  count = var.dns.enable_magic_dns && length(var.dns.nameservers) > 0 ? 1 : 0

  nameservers = var.dns.nameservers
}

resource "tailscale_dns_search_paths" "inferadb" {
  count = var.dns.enable_magic_dns && length(var.dns.search_paths) > 0 ? 1 : 0

  search_paths = var.dns.search_paths
}
