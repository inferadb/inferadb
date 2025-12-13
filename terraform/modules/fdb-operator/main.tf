# FDB Kubernetes Operator - Main
# ==============================
# Deploys the FoundationDB Kubernetes Operator via Helm
#
# The FDB Kubernetes Operator manages FoundationDB clusters in Kubernetes,
# handling deployment, scaling, upgrades, and failover automatically.

terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}

# Create namespace if requested
resource "kubernetes_namespace" "fdb_operator" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace

    labels = merge(
      {
        "app.kubernetes.io/name"       = "fdb-operator"
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "operator"
      },
      var.labels
    )
  }
}

# Install FDB Kubernetes Operator via Helm
resource "helm_release" "fdb_operator" {
  name       = var.helm_release_name
  namespace  = var.namespace
  repository = var.helm_chart_repository
  chart      = var.helm_chart_name
  version    = var.operator_version

  create_namespace = false # We manage namespace separately
  wait             = true
  timeout          = var.helm_timeout
  atomic           = var.helm_atomic

  # Core configuration
  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.operator_version
  }

  set {
    name  = "image.pullPolicy"
    value = var.image_pull_policy
  }

  set {
    name  = "replicaCount"
    value = var.replicas
  }

  # Resource limits
  set {
    name  = "resources.requests.cpu"
    value = var.resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.resources.requests.memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.resources.limits.memory
  }

  # Service account
  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  # CRD management
  set {
    name  = "installCRDs"
    value = var.install_crds
  }

  # Multi-cluster mode
  dynamic "set" {
    for_each = var.multi_cluster_mode ? [1] : []
    content {
      name  = "globalMode.enabled"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = var.cluster_label != "" ? [1] : []
    content {
      name  = "clusterLabel"
      value = var.cluster_label
    }
  }

  # Metrics
  set {
    name  = "metrics.enabled"
    value = var.enable_metrics
  }

  set {
    name  = "metrics.port"
    value = var.metrics_port
  }

  # Pod security context
  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = var.pod_security_context.run_as_non_root
  }

  set {
    name  = "podSecurityContext.runAsUser"
    value = var.pod_security_context.run_as_user
  }

  set {
    name  = "podSecurityContext.runAsGroup"
    value = var.pod_security_context.run_as_group
  }

  set {
    name  = "podSecurityContext.fsGroup"
    value = var.pod_security_context.fs_group
  }

  # Node selector
  dynamic "set" {
    for_each = var.node_selector
    content {
      name  = "nodeSelector.${set.key}"
      value = set.value
    }
  }

  # Tolerations
  dynamic "set" {
    for_each = { for idx, tol in var.tolerations : idx => tol }
    content {
      name  = "tolerations[${set.key}].key"
      value = set.value.key
    }
  }

  dynamic "set" {
    for_each = { for idx, tol in var.tolerations : idx => tol }
    content {
      name  = "tolerations[${set.key}].operator"
      value = set.value.operator
    }
  }

  dynamic "set" {
    for_each = { for idx, tol in var.tolerations : idx => tol if tol.value != null }
    content {
      name  = "tolerations[${set.key}].value"
      value = set.value.value
    }
  }

  dynamic "set" {
    for_each = { for idx, tol in var.tolerations : idx => tol }
    content {
      name  = "tolerations[${set.key}].effect"
      value = set.value.effect
    }
  }

  # Additional custom values
  values = var.helm_values != "" ? [var.helm_values] : []

  depends_on = [kubernetes_namespace.fdb_operator]
}

# ServiceMonitor for Prometheus Operator (optional)
resource "kubernetes_manifest" "service_monitor" {
  count = var.create_service_monitor && var.enable_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "${var.helm_release_name}-metrics"
      namespace = var.namespace
      labels = merge(
        {
          "app.kubernetes.io/name"       = "fdb-operator"
          "app.kubernetes.io/instance"   = var.helm_release_name
          "app.kubernetes.io/managed-by" = "terraform"
        },
        var.labels
      )
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"     = "fdb-kubernetes-operator"
          "app.kubernetes.io/instance" = var.helm_release_name
        }
      }

      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]

      namespaceSelector = {
        matchNames = [var.namespace]
      }
    }
  }

  depends_on = [helm_release.fdb_operator]
}
