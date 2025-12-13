# FDB Cluster Module - Variables
# ==============================
# Configuration variables for deploying a FoundationDB cluster

# Cluster identification
variable "cluster_name" {
  description = "Name of the FoundationDB cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the FDB cluster"
  type        = string
}

variable "create_namespace" {
  description = "Whether to create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

# FDB version and images
variable "fdb_version" {
  description = "FoundationDB version to deploy"
  type        = string
  default     = "7.3.43"
}

variable "fdb_image" {
  description = "FDB container image (leave empty for default)"
  type        = string
  default     = ""
}

variable "sidecar_image" {
  description = "FDB sidecar container image (leave empty for default)"
  type        = string
  default     = ""
}

# Cluster size and redundancy
variable "process_counts" {
  description = "Number of processes per role"
  type = object({
    storage            = optional(number, 3)
    log                = optional(number, 3)
    stateless          = optional(number, 3)
    cluster_controller = optional(number, 1)
    coordinator        = optional(number, 0) # 0 = auto-select
  })
  default = {
    storage            = 3
    log                = 3
    stateless          = 3
    cluster_controller = 1
    coordinator        = 0
  }
}

variable "redundancy_mode" {
  description = "FDB redundancy mode: single, double, triple, three_datacenter, three_data_hall"
  type        = string
  default     = "double"

  validation {
    condition     = contains(["single", "double", "triple", "three_datacenter", "three_data_hall"], var.redundancy_mode)
    error_message = "redundancy_mode must be one of: single, double, triple, three_datacenter, three_data_hall"
  }
}

variable "storage_engine" {
  description = "FDB storage engine: ssd, ssd-2, memory"
  type        = string
  default     = "ssd-2"

  validation {
    condition     = contains(["ssd", "ssd-2", "memory"], var.storage_engine)
    error_message = "storage_engine must be one of: ssd, ssd-2, memory"
  }
}

# Storage configuration
variable "volume_size" {
  description = "Size of persistent volume for each FDB pod"
  type        = string
  default     = "128Gi"
}

variable "storage_class" {
  description = "Kubernetes storage class for FDB volumes"
  type        = string
  default     = ""
}

# Resource limits
variable "resources" {
  description = "Resource requests and limits for FDB pods"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1"
      memory = "4Gi"
    }
    limits = {
      cpu    = "2"
      memory = "8Gi"
    }
  }
}

# Multi-region configuration
variable "region_id" {
  description = "Region identifier (e.g., 'us-west-1')"
  type        = string
  default     = ""
}

variable "datacenter_id" {
  description = "Datacenter identifier within the region (e.g., 'us-west-1a')"
  type        = string
  default     = ""
}

variable "is_primary" {
  description = "Whether this is the primary region (for Fearless DR)"
  type        = bool
  default     = true
}

variable "priority" {
  description = "Region priority (lower = higher priority for Fearless DR)"
  type        = number
  default     = 1
}

variable "satellite_logs" {
  description = "Number of satellite logs for Fearless DR"
  type        = number
  default     = 4
}

# Multi-region topology (for Fearless DR)
variable "multi_region_config" {
  description = "Multi-region configuration for Fearless DR"
  type = object({
    enabled = bool
    regions = list(object({
      id         = string
      priority   = number
      satellite  = optional(bool, false)
      data_halls = optional(list(string), [])
    }))
    usable_regions    = optional(number, 1)
    satellite_logs    = optional(number, 4)
    satellite_version = optional(string, "")
  })
  default = {
    enabled = false
    regions = []
  }
}

# Networking
variable "service_type" {
  description = "Kubernetes service type: ClusterIP, LoadBalancer, NodePort"
  type        = string
  default     = "ClusterIP"
}

variable "public_ip_source" {
  description = "Source for public IP: pod, service"
  type        = string
  default     = "pod"
}

# Tailscale sidecar for cross-region networking
variable "tailscale" {
  description = "Tailscale sidecar configuration for cross-region networking"
  type = object({
    enabled  = bool
    auth_key = optional(string, "")
    secret_ref = optional(object({
      name = string
      key  = string
    }), null)
    image      = optional(string, "tailscale/tailscale:v1.56.1")
    hostname   = optional(string, "")
    extra_args = optional(string, "--accept-routes")
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
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "128Mi"
      }
    })
  })
  default = {
    enabled = false
  }
}

# Security
variable "tls_enabled" {
  description = "Enable TLS for FDB communication"
  type        = bool
  default     = false
}

variable "tls_secret_name" {
  description = "Name of the TLS secret containing cert and key"
  type        = string
  default     = ""
}

# Pod configuration
variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Additional annotations to apply to FDB pods"
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Node selector for FDB pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for FDB pods"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  default = []
}

variable "pod_anti_affinity" {
  description = "Enable pod anti-affinity to spread FDB pods across nodes"
  type        = bool
  default     = true
}

variable "topology_spread_zones" {
  description = "Enable topology spread across availability zones"
  type        = bool
  default     = true
}

# Backup and restore
variable "backup_enabled" {
  description = "Enable FDB backup agent"
  type        = bool
  default     = false
}

variable "backup_bucket" {
  description = "S3/GCS bucket for backups"
  type        = string
  default     = ""
}

variable "backup_credentials_secret" {
  description = "Secret containing cloud credentials for backup"
  type        = string
  default     = ""
}

# Monitoring
variable "enable_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "create_service_monitor" {
  description = "Create ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = false
}

# Cluster file output
variable "cluster_file_secret_name" {
  description = "Name of the secret to store the FDB cluster file"
  type        = string
  default     = ""
}
