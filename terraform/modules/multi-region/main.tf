# Multi-Region Orchestration Module - Main
# =========================================
# Orchestrates deployment of InferaDB across multiple regions with Fearless DR
#
# This module coordinates:
# - FDB Kubernetes Operator deployment per region
# - FDB cluster deployment with multi-region configuration
# - InferaDB Engine and Control deployments
# - Cross-region networking via Tailscale

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

locals {
  # Find the primary region
  primary_region = [for r in var.regions : r if r.is_primary][0]

  # Sort regions by priority
  sorted_regions = sort([for r in var.regions : r.priority])

  # Build multi-region FDB configuration
  fdb_regions = [
    for r in var.regions : {
      id         = r.id
      priority   = r.priority
      satellite  = false
      data_halls = length(r.zones) > 0 ? r.zones : [r.id]
    }
  ]

  # Common labels
  common_labels = merge(
    {
      "app.kubernetes.io/part-of"    = "inferadb"
      "app.kubernetes.io/managed-by" = "terraform"
      "inferadb.io/multi-region"     = "true"
    },
    var.labels
  )

  # Multi-region config to pass to FDB clusters
  multi_region_config = var.fearless_dr.enabled ? {
    enabled        = true
    usable_regions = var.fearless_dr.usable_regions
    satellite_logs = var.fearless_dr.satellite_logs
    regions        = local.fdb_regions
    } : {
    enabled = false
    regions = []
  }
}

# Deploy FDB Operator in each region
module "fdb_operator" {
  source   = "../fdb-operator"
  for_each = { for r in var.regions : r.id => r }

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  namespace        = "${each.value.namespace}-system"
  create_namespace = true
  operator_version = var.operator_version
  fdb_version      = coalesce(each.value.fdb_version, var.fdb_version)

  # Enable multi-cluster mode for Fearless DR
  multi_cluster_mode = var.fearless_dr.enabled
  cluster_label      = each.value.id

  # Monitoring
  enable_metrics         = var.monitoring.enabled
  create_service_monitor = var.monitoring.create_service_monitors

  # Labels
  labels = merge(local.common_labels, {
    "topology.kubernetes.io/region" = each.value.id
  })
}

# Deploy FDB Cluster in each region
module "fdb_cluster" {
  source   = "../fdb-cluster"
  for_each = { for r in var.regions : r.id => r }

  providers = {
    kubernetes = kubernetes
  }

  cluster_name     = var.cluster_name
  namespace        = each.value.namespace
  create_namespace = true
  fdb_version      = coalesce(each.value.fdb_version, var.fdb_version)

  # Region configuration
  region_id     = each.value.id
  datacenter_id = length(each.value.zones) > 0 ? each.value.zones[0] : each.value.id
  is_primary    = each.value.is_primary
  priority      = each.value.priority

  # Cluster sizing
  process_counts  = each.value.process_counts
  redundancy_mode = var.redundancy_mode
  storage_engine  = var.storage_engine
  volume_size     = var.volume_size
  storage_class   = each.value.storage_class

  # Resources
  resources = each.value.resources != null ? each.value.resources : {
    requests = {
      cpu    = "1"
      memory = "4Gi"
    }
    limits = {
      cpu    = "2"
      memory = "8Gi"
    }
  }

  # Multi-region configuration
  multi_region_config = local.multi_region_config

  # Tailscale sidecar for cross-region networking
  tailscale = var.tailscale.enabled ? {
    enabled = true
    secret_ref = {
      name = var.tailscale.secret_name
      key  = var.tailscale.secret_key
    }
    image    = var.tailscale.image
    hostname = "fdb-${each.value.id}"
    } : {
    enabled = false
  }

  # Node selection
  node_selector = each.value.node_selector
  tolerations   = each.value.tolerations

  # Monitoring
  enable_metrics         = var.monitoring.enabled
  create_service_monitor = var.monitoring.create_service_monitors

  # Labels
  labels = merge(local.common_labels, {
    "topology.kubernetes.io/region" = each.value.id
  })

  depends_on = [module.fdb_operator]
}

# Create Tailscale auth secret in each region (if not using external secrets)
resource "kubernetes_secret" "tailscale_auth" {
  for_each = var.tailscale.enabled && var.tailscale.auth_key != "" ? { for r in var.regions : r.id => r } : {}

  metadata {
    name      = var.tailscale.secret_name
    namespace = each.value.namespace
    labels    = local.common_labels
  }

  data = {
    (var.tailscale.secret_key) = var.tailscale.auth_key
  }

  type = "Opaque"
}

# Deploy InferaDB Engine in each region
resource "kubernetes_deployment" "engine" {
  for_each = var.engine.enabled ? { for r in var.regions : r.id => r } : {}

  metadata {
    name      = "inferadb-engine"
    namespace = each.value.namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"        = "inferadb-engine"
      "app.kubernetes.io/component"   = "engine"
      "topology.kubernetes.io/region" = each.value.id
    })
  }

  spec {
    replicas = var.engine.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "inferadb-engine"
        "app.kubernetes.io/component" = "engine"
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name"        = "inferadb-engine"
          "app.kubernetes.io/component"   = "engine"
          "topology.kubernetes.io/region" = each.value.id
        })
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = "inferadb-engine"

        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          run_as_group    = 65532
          fs_group        = 65532
        }

        container {
          name              = "inferadb-engine"
          image             = var.engine.image
          image_pull_policy = var.engine.image_pull_policy

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          port {
            name           = "grpc"
            container_port = 8081
            protocol       = "TCP"
          }

          port {
            name           = "mesh"
            container_port = 8082
            protocol       = "TCP"
          }

          env {
            name  = "RUST_LOG"
            value = "info"
          }

          env {
            name  = "INFERADB__STORAGE"
            value = "foundationdb"
          }

          env {
            name  = "INFERADB__FOUNDATIONDB__CLUSTER_FILE"
            value = "/etc/foundationdb/fdb.cluster"
          }

          env {
            name  = "INFERADB__REPLICATION__LOCAL_REGION"
            value = each.value.id
          }

          env {
            name  = "INFERADB__REPLICATION__STRATEGY"
            value = "ActiveActive"
          }

          resources {
            requests = {
              cpu    = var.engine.resources.requests.cpu
              memory = var.engine.resources.requests.memory
            }
            limits = {
              cpu    = var.engine.resources.limits.cpu
              memory = var.engine.resources.limits.memory
            }
          }

          volume_mount {
            name       = "fdb-cluster-file"
            mount_path = "/etc/foundationdb"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          liveness_probe {
            http_get {
              path = "/livez"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65532
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        # Tailscale sidecar for cross-region communication
        dynamic "container" {
          for_each = var.tailscale.enabled ? [1] : []
          content {
            name              = "tailscale"
            image             = var.tailscale.image
            image_pull_policy = "IfNotPresent"

            env {
              name = "TS_AUTHKEY"
              value_from {
                secret_key_ref {
                  name = var.tailscale.secret_name
                  key  = var.tailscale.secret_key
                }
              }
            }

            env {
              name  = "TS_KUBE_SECRET"
              value = ""
            }

            env {
              name  = "TS_USERSPACE"
              value = "true"
            }

            env {
              name  = "TS_HOSTNAME"
              value = "engine-${each.value.id}"
            }

            resources {
              requests = {
                cpu    = "50m"
                memory = "64Mi"
              }
              limits = {
                cpu    = "200m"
                memory = "128Mi"
              }
            }

            security_context {
              run_as_user  = 0
              run_as_group = 0
              capabilities {
                add = ["NET_ADMIN"]
              }
            }
          }
        }

        volume {
          name = "fdb-cluster-file"
          config_map {
            name = module.fdb_cluster[each.key].cluster_file_configmap_name
            items {
              key  = "fdb.cluster"
              path = "fdb.cluster"
            }
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        # Spread across nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_labels = {
                    "app.kubernetes.io/name" = "inferadb-engine"
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        # Spread across zones
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = {
              "app.kubernetes.io/name" = "inferadb-engine"
            }
          }
        }
      }
    }
  }

  depends_on = [module.fdb_cluster]
}

# Engine Service
resource "kubernetes_service" "engine" {
  for_each = var.engine.enabled ? { for r in var.regions : r.id => r } : {}

  metadata {
    name      = "inferadb-engine"
    namespace = each.value.namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"      = "inferadb-engine"
      "app.kubernetes.io/component" = "engine"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "inferadb-engine"
      "app.kubernetes.io/component" = "engine"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    port {
      name        = "grpc"
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }

    port {
      name        = "mesh"
      port        = 8082
      target_port = 8082
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Engine headless service for peer discovery
resource "kubernetes_service" "engine_headless" {
  for_each = var.engine.enabled ? { for r in var.regions : r.id => r } : {}

  metadata {
    name      = "inferadb-engine-headless"
    namespace = each.value.namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"      = "inferadb-engine"
      "app.kubernetes.io/component" = "engine"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "inferadb-engine"
      "app.kubernetes.io/component" = "engine"
    }

    port {
      name        = "grpc"
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }

    cluster_ip = "None"
  }
}
