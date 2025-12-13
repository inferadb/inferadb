# InferaDB AWS Multi-Region - Variables
# ======================================

# =============================================================================
# Region Configuration
# =============================================================================

variable "primary_region" {
  description = "AWS region for primary deployment"
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "AWS region for DR deployment"
  type        = string
  default     = "eu-west-1"
}

variable "primary_vpc_cidr" {
  description = "CIDR block for primary region VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dr_vpc_cidr" {
  description = "CIDR block for DR region VPC"
  type        = string
  default     = "10.1.0.0/16"
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

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

# =============================================================================
# Node Group Configuration
# =============================================================================

variable "general_instance_types" {
  description = "Instance types for general workload nodes"
  type        = list(string)
  default     = ["m6i.xlarge", "m6i.2xlarge"]
}

variable "general_min_size" {
  description = "Minimum size for general node group"
  type        = number
  default     = 2
}

variable "general_max_size" {
  description = "Maximum size for general node group"
  type        = number
  default     = 10
}

variable "general_desired_size" {
  description = "Desired size for general node group"
  type        = number
  default     = 3
}

variable "fdb_instance_types" {
  description = "Instance types for FDB dedicated nodes"
  type        = list(string)
  default     = ["i3.xlarge", "i3.2xlarge"]
}

variable "fdb_node_count" {
  description = "Number of FDB dedicated nodes"
  type        = number
  default     = 3
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
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "InferaDB"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
