# FDB Cluster Module - Main
# =========================
# Deploys a FoundationDB cluster using the FDB Kubernetes Operator
#
# This module creates a FoundationDBCluster CRD that the operator
# watches and reconciles into a running FDB cluster.

terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

locals {
  # Default cluster file secret name
  cluster_file_secret = var.cluster_file_secret_name != "" ? var.cluster_file_secret_name : "${var.cluster_name}-cluster-file"

  # Common labels
  common_labels = merge(
    {
      "app.kubernetes.io/name"       = "foundationdb"
      "app.kubernetes.io/instance"   = var.cluster_name
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "database"
    },
    var.region_id != "" ? { "topology.kubernetes.io/region" = var.region_id } : {},
    var.labels
  )

  # Build multi-region configuration
  multi_region_spec = var.multi_region_config.enabled ? {
    usable_regions = var.multi_region_config.usable_regions
    regions = [
      for region in var.multi_region_config.regions : {
        datacenters = [
          for idx, hall in coalesce(region.data_halls, [region.id]) : {
            id        = hall
            priority  = region.priority
            satellite = region.satellite ? 1 : 0
          }
        ]
      }
    ]
    satellite_logs = var.multi_region_config.satellite_logs
  } : null

  # Tailscale sidecar container spec
  tailscale_sidecar = var.tailscale.enabled ? {
    name  = "tailscale"
    image = var.tailscale.image
    env = concat(
      var.tailscale.secret_ref != null ? [
        {
          name = "TS_AUTHKEY"
          valueFrom = {
            secretKeyRef = {
              name = var.tailscale.secret_ref.name
              key  = var.tailscale.secret_ref.key
            }
          }
        }
        ] : (var.tailscale.auth_key != "" ? [
          {
            name  = "TS_AUTHKEY"
            value = var.tailscale.auth_key
          }
      ] : []),
      [
        {
          name  = "TS_KUBE_SECRET"
          value = ""
        },
        {
          name  = "TS_USERSPACE"
          value = "true"
        },
        {
          name  = "TS_ACCEPT_DNS"
          value = "false"
        }
      ]
    )
    args = var.tailscale.extra_args != "" ? split(" ", var.tailscale.extra_args) : []
    resources = {
      requests = var.tailscale.resources.requests
      limits   = var.tailscale.resources.limits
    }
    securityContext = {
      runAsNonRoot = false
      runAsUser    = 0
      capabilities = {
        add = ["NET_ADMIN"]
      }
    }
  } : null
}

# Create namespace if requested
resource "kubernetes_namespace" "fdb" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name   = var.namespace
    labels = local.common_labels
  }
}

# FoundationDB Cluster CRD
resource "kubernetes_manifest" "fdb_cluster" {
  manifest = {
    apiVersion = "apps.foundationdb.org/v1beta2"
    kind       = "FoundationDBCluster"

    metadata = {
      name      = var.cluster_name
      namespace = var.namespace
      labels    = local.common_labels
      annotations = merge(
        var.annotations,
        var.region_id != "" ? {
          "inferadb.io/region"     = var.region_id
          "inferadb.io/is-primary" = tostring(var.is_primary)
        } : {}
      )
    }

    spec = {
      version = var.fdb_version

      # Process counts
      processCounts = {
        storage           = var.process_counts.storage
        log               = var.process_counts.log
        stateless         = var.process_counts.stateless
        clusterController = var.process_counts.cluster_controller
        coordinator       = var.process_counts.coordinator > 0 ? var.process_counts.coordinator : null
      }

      # Database configuration
      databaseConfiguration = merge(
        {
          redundancy_mode = var.redundancy_mode
          storage_engine  = var.storage_engine
        },
        # Multi-region configuration
        local.multi_region_spec != null ? {
          usable_regions = local.multi_region_spec.usable_regions
          regions        = local.multi_region_spec.regions
        } : {},
        # Region/datacenter locality
        var.region_id != "" || var.datacenter_id != "" ? {
          regions = var.multi_region_config.enabled ? null : [
            {
              datacenters = [
                {
                  id       = var.datacenter_id != "" ? var.datacenter_id : var.region_id
                  priority = var.priority
                }
              ]
            }
          ]
        } : {}
      )

      # Routing configuration
      routing = {
        publicIPSource = var.public_ip_source
      }

      # Pod template
      processes = {
        general = {
          podTemplate = {
            spec = {
              # Security context
              securityContext = {
                fsGroup = 4059
              }

              # Main container configuration
              containers = concat(
                [
                  {
                    name = "foundationdb"
                    resources = {
                      requests = var.resources.requests
                      limits   = var.resources.limits
                    }
                    securityContext = {
                      runAsUser  = 4059
                      runAsGroup = 4059
                    }
                  }
                ],
                # Tailscale sidecar if enabled
                local.tailscale_sidecar != null ? [local.tailscale_sidecar] : []
              )

              # Node selector
              nodeSelector = length(var.node_selector) > 0 ? var.node_selector : null

              # Tolerations
              tolerations = length(var.tolerations) > 0 ? [
                for tol in var.tolerations : {
                  key      = tol.key
                  operator = tol.operator
                  value    = tol.value
                  effect   = tol.effect
                }
              ] : null

              # Pod anti-affinity
              affinity = var.pod_anti_affinity ? {
                podAntiAffinity = {
                  preferredDuringSchedulingIgnoredDuringExecution = [
                    {
                      weight = 100
                      podAffinityTerm = {
                        labelSelector = {
                          matchLabels = {
                            "foundationdb.org/fdb-cluster-name" = var.cluster_name
                          }
                        }
                        topologyKey = "kubernetes.io/hostname"
                      }
                    }
                  ]
                }
              } : null

              # Topology spread
              topologySpreadConstraints = var.topology_spread_zones ? [
                {
                  maxSkew           = 1
                  topologyKey       = "topology.kubernetes.io/zone"
                  whenUnsatisfiable = "ScheduleAnyway"
                  labelSelector = {
                    matchLabels = {
                      "foundationdb.org/fdb-cluster-name" = var.cluster_name
                    }
                  }
                }
              ] : null
            }
          }

          # Volume claim template for persistent storage
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.volume_size
                }
              }
              storageClassName = var.storage_class != "" ? var.storage_class : null
            }
          }
        }
      }

      # FDB locality settings for multi-region
      faultDomain = var.region_id != "" ? {
        key   = "foundationdb.org/fdb-zone-id"
        value = var.datacenter_id != "" ? var.datacenter_id : var.region_id
      } : null

      # Sidecar configuration
      sidecarContainer = {
        enableLivenessProbe  = true
        enableReadinessProbe = true
      }

      # TLS configuration
      mainContainer = var.tls_enabled ? {
        enableTls = true
      } : null

      # Backup configuration
      backupDeploymentAgents = var.backup_enabled ? {
        podTemplate = {
          spec = {
            containers = [
              {
                name = "foundationdb"
                env = [
                  {
                    name  = "FDB_BLOB_CREDENTIALS"
                    value = var.backup_bucket
                  }
                ]
              }
            ]
            volumes = var.backup_credentials_secret != "" ? [
              {
                name = "backup-credentials"
                secret = {
                  secretName = var.backup_credentials_secret
                }
              }
            ] : null
          }
        }
      } : null

      # Cluster file auto-generation
      connectionString = "" # Let operator generate
    }
  }

  depends_on = [kubernetes_namespace.fdb]
}

# Secret to store cluster file for application consumption
resource "kubernetes_secret" "cluster_file" {
  metadata {
    name      = local.cluster_file_secret
    namespace = var.namespace
    labels    = local.common_labels
  }

  # Data will be populated by the FDB operator
  # This secret is created as a placeholder and will be updated
  data = {
    "fdb.cluster" = ""
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [kubernetes_manifest.fdb_cluster]
}

# ConfigMap for FDB cluster file (alternative to secret)
resource "kubernetes_config_map" "cluster_file" {
  metadata {
    name      = "${var.cluster_name}-config"
    namespace = var.namespace
    labels    = local.common_labels
  }

  # Data will be populated by the FDB operator
  data = {
    "fdb.cluster" = ""
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [kubernetes_manifest.fdb_cluster]
}

# ServiceMonitor for Prometheus Operator (optional)
resource "kubernetes_manifest" "service_monitor" {
  count = var.create_service_monitor && var.enable_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "${var.cluster_name}-fdb"
      namespace = var.namespace
      labels    = local.common_labels
    }

    spec = {
      selector = {
        matchLabels = {
          "foundationdb.org/fdb-cluster-name" = var.cluster_name
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

  depends_on = [kubernetes_manifest.fdb_cluster]
}
