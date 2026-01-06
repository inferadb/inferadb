# Multi-Region Orchestration Module - Variables
# ==============================================
# Configuration variables for multi-region InferaDB deployment

# Region configuration
variable "regions" {
  description = "List of regions to deploy InferaDB"
  type = list(object({
    id         = string                # Region identifier (e.g., "us-west-1")
    name       = string                # Human-readable name
    is_primary = optional(bool, false) # Is this the primary region?
    priority   = optional(number, 1)   # Failover priority (lower = higher priority)

    # Kubernetes provider configuration
    kubernetes = object({
      config_path    = optional(string, "")
      config_context = optional(string, "")
      host           = optional(string, "")
      token          = optional(string, "")
      cluster_ca     = optional(string, "")
    })

    # Regional overrides
    namespace     = optional(string, "inferadb")
    fdb_version   = optional(string, "")
    storage_class = optional(string, "")

    # FDB cluster sizing
    process_counts = optional(object({
      storage   = number
      log       = number
      stateless = number
      }), {
      storage   = 3
      log       = 3
      stateless = 3
    })

    # Resource limits
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    }), null)

    # Node selection
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key      = string
      operator = string
      value    = optional(string)
      effect   = string
    })), [])

    # Availability zones
    zones = optional(list(string), [])
  }))

  validation {
    condition     = length([for r in var.regions : r if r.is_primary]) == 1
    error_message = "Exactly one region must be marked as primary (is_primary = true)"
  }
}

# Global settings
variable "cluster_name" {
  description = "Base name for the FDB cluster (will be suffixed with region)"
  type        = string
  default     = "inferadb-fdb"
}

variable "fdb_version" {
  description = "Default FoundationDB version (can be overridden per region)"
  type        = string
  default     = "7.3.43"
}

variable "operator_version" {
  description = "FDB Kubernetes Operator version"
  type        = string
  default     = "1.45.0"
}

# Redundancy configuration
variable "redundancy_mode" {
  description = "FDB redundancy mode for all regions"
  type        = string
  default     = "double"
}

variable "storage_engine" {
  description = "FDB storage engine for all regions"
  type        = string
  default     = "ssd-2"
}

variable "volume_size" {
  description = "Default volume size for FDB pods"
  type        = string
  default     = "128Gi"
}

# Fearless DR configuration
variable "fearless_dr" {
  description = "Fearless DR configuration"
  type = object({
    enabled           = bool
    usable_regions    = optional(number, 1)  # Number of regions that must be available
    satellite_logs    = optional(number, 4)  # Number of satellite log processes
    satellite_version = optional(string, "") # Optional satellite version
  })
  default = {
    enabled = true
  }
}

# Tailscale networking
variable "tailscale" {
  description = "Tailscale configuration for cross-region networking"
  type = object({
    enabled     = bool
    auth_key    = optional(string, "") # Global auth key (can be overridden per region)
    secret_name = optional(string, "tailscale-auth")
    secret_key  = optional(string, "authkey")
    image       = optional(string, "tailscale/tailscale:v1.56.1")
  })
  default = {
    enabled = true
  }
}

# InferaDB Engine configuration
variable "engine" {
  description = "InferaDB Engine deployment configuration"
  type = object({
    enabled           = bool
    replicas          = optional(number, 3)
    image             = optional(string, "inferadb-engine:latest")
    image_pull_policy = optional(string, "IfNotPresent")
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
      }), {
      requests = {
        cpu    = "500m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "2000m"
        memory = "2Gi"
      }
    })
  })
  default = {
    enabled = true
  }
}

# InferaDB Control configuration
variable "control" {
  description = "InferaDB Control deployment configuration"
  type = object({
    enabled           = bool
    replicas          = optional(number, 2)
    image             = optional(string, "inferadb-control:latest")
    image_pull_policy = optional(string, "IfNotPresent")
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
      }), {
      requests = {
        cpu    = "250m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    })
  })
  default = {
    enabled = true
  }
}

# Monitoring
variable "monitoring" {
  description = "Monitoring configuration"
  type = object({
    enabled                 = bool
    create_service_monitors = optional(bool, false)
  })
  default = {
    enabled = true
  }
}

# Labels and annotations
variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Additional annotations to apply to all resources"
  type        = map(string)
  default     = {}
}
