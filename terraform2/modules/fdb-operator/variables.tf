# FDB Kubernetes Operator - Variables
# ===================================
# Configuration variables for deploying the FoundationDB Kubernetes Operator

variable "namespace" {
  description = "Kubernetes namespace to deploy the FDB operator"
  type        = string
  default     = "fdb-operator"
}

variable "create_namespace" {
  description = "Whether to create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "operator_version" {
  description = "Version of the FDB Kubernetes Operator"
  type        = string
  default     = "1.45.0"
}

variable "fdb_version" {
  description = "Default FoundationDB version to use"
  type        = string
  default     = "7.3.43"
}

variable "image_repository" {
  description = "Docker image repository for the FDB operator"
  type        = string
  default     = "foundationdb/fdb-kubernetes-operator"
}

variable "image_pull_policy" {
  description = "Image pull policy for the operator"
  type        = string
  default     = "IfNotPresent"
}

variable "replicas" {
  description = "Number of operator replicas (for HA)"
  type        = number
  default     = 1
}

variable "resources" {
  description = "Resource requests and limits for the operator"
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
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Additional annotations to apply to the operator deployment"
  type        = map(string)
  default     = {}
}

# Multi-cluster coordination settings
variable "multi_cluster_mode" {
  description = "Enable multi-cluster coordination mode for cross-region FDB deployments"
  type        = bool
  default     = false
}

variable "cluster_label" {
  description = "Label to identify this cluster in multi-cluster mode (e.g., 'us-west-1')"
  type        = string
  default     = ""
}

# CRD management
variable "install_crds" {
  description = "Whether to install FDB CRDs (disable if managing CRDs separately)"
  type        = bool
  default     = true
}

variable "crd_upgrade_strategy" {
  description = "CRD upgrade strategy: 'Skip', 'CreateReplace', 'UpdateReplace'"
  type        = string
  default     = "CreateReplace"
}

# Security settings
variable "service_account_name" {
  description = "Name of the service account for the operator"
  type        = string
  default     = "fdb-kubernetes-operator"
}

variable "pod_security_context" {
  description = "Pod security context for the operator"
  type = object({
    run_as_non_root = bool
    run_as_user     = number
    run_as_group    = number
    fs_group        = number
  })
  default = {
    run_as_non_root = true
    run_as_user     = 4059
    run_as_group    = 4059
    fs_group        = 4059
  }
}

# Monitoring
variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Port for Prometheus metrics"
  type        = number
  default     = 8080
}

variable "create_service_monitor" {
  description = "Create ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = false
}

# Node selection
variable "node_selector" {
  description = "Node selector for operator pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for operator pods"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  default = []
}

variable "affinity" {
  description = "Affinity rules for operator pods (JSON-encoded)"
  type        = any
  default     = null
}

# Helm chart settings
variable "helm_release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "fdb-operator"
}

variable "helm_chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://foundationdb.github.io/fdb-kubernetes-operator/"
}

variable "helm_chart_name" {
  description = "Name of the Helm chart"
  type        = string
  default     = "fdb-kubernetes-operator"
}

variable "helm_timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 300
}

variable "helm_atomic" {
  description = "If true, installation process purges chart on fail"
  type        = bool
  default     = true
}

variable "helm_values" {
  description = "Additional Helm values to merge (as YAML string)"
  type        = string
  default     = ""
}
