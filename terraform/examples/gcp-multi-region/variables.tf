# InferaDB GCP Multi-Region - Variables
# ======================================

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

# =============================================================================
# Region Configuration
# =============================================================================

variable "primary_region" {
  description = "GCP region for primary deployment"
  type        = string
  default     = "us-west1"
}

variable "dr_region" {
  description = "GCP region for DR deployment"
  type        = string
  default     = "europe-west1"
}

variable "primary_subnet_cidr" {
  description = "CIDR block for primary region subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "primary_pods_cidr" {
  description = "CIDR block for primary region pods"
  type        = string
  default     = "10.0.16.0/20"
}

variable "primary_services_cidr" {
  description = "CIDR block for primary region services"
  type        = string
  default     = "10.0.32.0/20"
}

variable "dr_subnet_cidr" {
  description = "CIDR block for DR region subnet"
  type        = string
  default     = "10.1.0.0/20"
}

variable "dr_pods_cidr" {
  description = "CIDR block for DR region pods"
  type        = string
  default     = "10.1.16.0/20"
}

variable "dr_services_cidr" {
  description = "CIDR block for DR region services"
  type        = string
  default     = "10.1.32.0/20"
}

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Base name for the cluster resources"
  type        = string
  default     = "inferadb"
}

variable "namespace" {
  description = "Kubernetes namespace for InferaDB"
  type        = string
  default     = "inferadb"
}

# =============================================================================
# Node Pool Configuration
# =============================================================================

variable "general_machine_type" {
  description = "Machine type for general workload nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "general_min_size" {
  description = "Minimum size for general node pool"
  type        = number
  default     = 2
}

variable "general_max_size" {
  description = "Maximum size for general node pool"
  type        = number
  default     = 10
}

variable "general_desired_size" {
  description = "Desired size for general node pool"
  type        = number
  default     = 3
}

variable "fdb_machine_type" {
  description = "Machine type for FDB dedicated nodes"
  type        = string
  default     = "n2-standard-4"
}

variable "fdb_node_count" {
  description = "Number of FDB dedicated nodes"
  type        = number
  default     = 3
}

variable "fdb_local_ssd_count" {
  description = "Number of local SSDs to attach to FDB nodes"
  type        = number
  default     = 1
}

# =============================================================================
# FoundationDB Configuration
# =============================================================================

variable "fdb_version" {
  description = "FoundationDB version"
  type        = string
  default     = "7.3.43"
}

variable "fdb_storage_count" {
  description = "Number of FDB storage processes"
  type        = number
  default     = 3
}

variable "fdb_log_count" {
  description = "Number of FDB log processes"
  type        = number
  default     = 3
}

variable "fdb_stateless_count" {
  description = "Number of FDB stateless processes"
  type        = number
  default     = 3
}

variable "fdb_redundancy_mode" {
  description = "FDB redundancy mode"
  type        = string
  default     = "double"
}

variable "fdb_satellite_logs" {
  description = "Number of satellite log processes for Fearless DR"
  type        = number
  default     = 4
}

# =============================================================================
# InferaDB Configuration
# =============================================================================

variable "engine_replicas" {
  description = "Number of InferaDB Engine replicas per region"
  type        = number
  default     = 3
}

variable "engine_image" {
  description = "InferaDB Engine container image"
  type        = string
  default     = "inferadb-engine:latest"
}

variable "control_replicas" {
  description = "Number of InferaDB Control replicas per region"
  type        = number
  default     = 2
}

variable "control_image" {
  description = "InferaDB Control container image"
  type        = string
  default     = "inferadb-control:latest"
}

# =============================================================================
# Tailscale Configuration
# =============================================================================

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name"
  type        = string
}

variable "tailscale_api_key" {
  description = "Tailscale API key for managing ACLs"
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for device registration"
  type        = string
  sensitive   = true
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "enable_ssh" {
  description = "Enable SSH access to pods via Tailscale"
  type        = bool
  default     = false
}

variable "ssh_allowed_users" {
  description = "Users allowed SSH access"
  type        = list(string)
  default     = ["autogroup:admin"]
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "enable_monitoring" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "create_service_monitors" {
  description = "Create ServiceMonitors for Prometheus Operator"
  type        = bool
  default     = false
}

# =============================================================================
# Labels
# =============================================================================

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    project     = "inferadb"
    environment = "production"
    managed_by  = "terraform"
  }
}
