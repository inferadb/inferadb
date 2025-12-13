# InferaDB GCP Multi-Region Deployment
# =====================================
# This example deploys InferaDB across two GCP regions with Fearless DR
#
# Architecture:
# - us-west1: Primary region with GKE + FDB + InferaDB
# - europe-west1: DR region with GKE + FDB + InferaDB
# - Tailscale: Cross-region mesh networking
# - FDB Fearless DR: Automatic data replication

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13"
    }
  }

  # Recommended: Store state remotely
  # backend "gcs" {
  #   bucket = "your-terraform-state"
  #   prefix = "inferadb/multi-region"
  # }
}

# =============================================================================
# Providers
# =============================================================================

# Google Provider
provider "google" {
  project = var.project_id
  region  = var.primary_region
}

# Kubernetes Providers (configured after GKE is created)
provider "kubernetes" {
  alias = "primary"

  host                   = "https://${module.gke_primary.endpoint}"
  cluster_ca_certificate = base64decode(module.gke_primary.ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "kubernetes" {
  alias = "dr"

  host                   = "https://${module.gke_dr.endpoint}"
  cluster_ca_certificate = base64decode(module.gke_dr.ca_certificate)
  token                  = data.google_client_config.default.access_token
}

# Helm Providers
provider "helm" {
  alias = "primary"

  kubernetes {
    host                   = "https://${module.gke_primary.endpoint}"
    cluster_ca_certificate = base64decode(module.gke_primary.ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

provider "helm" {
  alias = "dr"

  kubernetes {
    host                   = "https://${module.gke_dr.endpoint}"
    cluster_ca_certificate = base64decode(module.gke_dr.ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

# Tailscale Provider
provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}

# =============================================================================
# Data Sources
# =============================================================================

data "google_client_config" "default" {}

data "google_compute_zones" "primary" {
  region = var.primary_region
}

data "google_compute_zones" "dr" {
  region = var.dr_region
}

# =============================================================================
# VPC - Primary Region
# =============================================================================

module "vpc_primary" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "${var.cluster_name}-primary"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name   = "${var.cluster_name}-primary-nodes"
      subnet_ip     = var.primary_subnet_cidr
      subnet_region = var.primary_region
    }
  ]

  secondary_ranges = {
    "${var.cluster_name}-primary-nodes" = [
      {
        range_name    = "pods"
        ip_cidr_range = var.primary_pods_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = var.primary_services_cidr
      }
    ]
  }
}

# =============================================================================
# VPC - DR Region
# =============================================================================

module "vpc_dr" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "${var.cluster_name}-dr"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name   = "${var.cluster_name}-dr-nodes"
      subnet_ip     = var.dr_subnet_cidr
      subnet_region = var.dr_region
    }
  ]

  secondary_ranges = {
    "${var.cluster_name}-dr-nodes" = [
      {
        range_name    = "pods"
        ip_cidr_range = var.dr_pods_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = var.dr_services_cidr
      }
    ]
  }
}

# =============================================================================
# Cloud Router & NAT - Primary Region
# =============================================================================

resource "google_compute_router" "primary" {
  name    = "${var.cluster_name}-primary-router"
  project = var.project_id
  region  = var.primary_region
  network = module.vpc_primary.network_id
}

resource "google_compute_router_nat" "primary" {
  name                               = "${var.cluster_name}-primary-nat"
  project                            = var.project_id
  router                             = google_compute_router.primary.name
  region                             = var.primary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# =============================================================================
# Cloud Router & NAT - DR Region
# =============================================================================

resource "google_compute_router" "dr" {
  name    = "${var.cluster_name}-dr-router"
  project = var.project_id
  region  = var.dr_region
  network = module.vpc_dr.network_id
}

resource "google_compute_router_nat" "dr" {
  name                               = "${var.cluster_name}-dr-nat"
  project                            = var.project_id
  router                             = google_compute_router.dr.name
  region                             = var.dr_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# =============================================================================
# GKE - Primary Region
# =============================================================================

module "gke_primary" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 30.0"

  project_id = var.project_id
  name       = "${var.cluster_name}-primary"
  region     = var.primary_region
  zones      = slice(data.google_compute_zones.primary.names, 0, 3)

  network           = module.vpc_primary.network_name
  subnetwork        = "${var.cluster_name}-primary-nodes"
  ip_range_pods     = "pods"
  ip_range_services = "services"

  release_channel = "REGULAR"

  # Enable Workload Identity
  workload_identity_enabled = true

  # Enable network policy
  network_policy = true

  node_pools = [
    {
      name          = "general"
      machine_type  = var.general_machine_type
      min_count     = var.general_min_size
      max_count     = var.general_max_size
      initial_count = var.general_desired_size
      disk_size_gb  = 100
      disk_type     = "pd-ssd"
      auto_upgrade  = true
      auto_repair   = true
      node_metadata = "GKE_METADATA"

      node_labels = {
        workload = "general"
      }
    },
    {
      name            = "fdb"
      machine_type    = var.fdb_machine_type
      min_count       = var.fdb_node_count
      max_count       = var.fdb_node_count
      initial_count   = var.fdb_node_count
      disk_size_gb    = 200
      disk_type       = "pd-ssd"
      local_ssd_count = var.fdb_local_ssd_count
      auto_upgrade    = true
      auto_repair     = true
      node_metadata   = "GKE_METADATA"

      node_labels = {
        workload = "fdb"
      }
    }
  ]

  node_pools_taints = {
    fdb = [
      {
        key    = "dedicated"
        value  = "fdb"
        effect = "NO_SCHEDULE"
      }
    ]
  }

  depends_on = [module.vpc_primary]
}

# =============================================================================
# GKE - DR Region
# =============================================================================

module "gke_dr" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 30.0"

  project_id = var.project_id
  name       = "${var.cluster_name}-dr"
  region     = var.dr_region
  zones      = slice(data.google_compute_zones.dr.names, 0, 3)

  network           = module.vpc_dr.network_name
  subnetwork        = "${var.cluster_name}-dr-nodes"
  ip_range_pods     = "pods"
  ip_range_services = "services"

  release_channel = "REGULAR"

  workload_identity_enabled = true
  network_policy            = true

  node_pools = [
    {
      name          = "general"
      machine_type  = var.general_machine_type
      min_count     = var.general_min_size
      max_count     = var.general_max_size
      initial_count = var.general_desired_size
      disk_size_gb  = 100
      disk_type     = "pd-ssd"
      auto_upgrade  = true
      auto_repair   = true
      node_metadata = "GKE_METADATA"

      node_labels = {
        workload = "general"
      }
    },
    {
      name            = "fdb"
      machine_type    = var.fdb_machine_type
      min_count       = var.fdb_node_count
      max_count       = var.fdb_node_count
      initial_count   = var.fdb_node_count
      disk_size_gb    = 200
      disk_type       = "pd-ssd"
      local_ssd_count = var.fdb_local_ssd_count
      auto_upgrade    = true
      auto_repair     = true
      node_metadata   = "GKE_METADATA"

      node_labels = {
        workload = "fdb"
      }
    }
  ]

  node_pools_taints = {
    fdb = [
      {
        key    = "dedicated"
        value  = "fdb"
        effect = "NO_SCHEDULE"
      }
    ]
  }

  depends_on = [module.vpc_dr]
}

# =============================================================================
# Tailscale ACLs
# =============================================================================

module "tailscale_acls" {
  source = "../../modules/tailscale-acls"

  tailnet = var.tailscale_tailnet
  api_key = var.tailscale_api_key

  regions = [
    { id = var.primary_region, name = "Primary (${var.primary_region})" },
    { id = var.dr_region, name = "DR (${var.dr_region})" }
  ]

  enable_ssh        = var.enable_ssh
  ssh_allowed_users = var.ssh_allowed_users
}

# =============================================================================
# InferaDB Multi-Region Deployment
# =============================================================================

module "inferadb" {
  source = "../../modules/multi-region"

  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }

  regions = [
    {
      id         = var.primary_region
      name       = "Primary"
      is_primary = true
      priority   = 1
      namespace  = var.namespace

      kubernetes = {
        config_context = "gke_${var.project_id}_${var.primary_region}_${var.cluster_name}-primary"
      }

      process_counts = {
        storage   = var.fdb_storage_count
        log       = var.fdb_log_count
        stateless = var.fdb_stateless_count
      }

      node_selector = {
        workload = "fdb"
      }

      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "fdb"
          effect   = "NoSchedule"
        }
      ]

      zones = slice(data.google_compute_zones.primary.names, 0, 3)
    },
    {
      id         = var.dr_region
      name       = "DR"
      is_primary = false
      priority   = 2
      namespace  = var.namespace

      kubernetes = {
        config_context = "gke_${var.project_id}_${var.dr_region}_${var.cluster_name}-dr"
      }

      process_counts = {
        storage   = var.fdb_storage_count
        log       = var.fdb_log_count
        stateless = var.fdb_stateless_count
      }

      node_selector = {
        workload = "fdb"
      }

      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "fdb"
          effect   = "NoSchedule"
        }
      ]

      zones = slice(data.google_compute_zones.dr.names, 0, 3)
    }
  ]

  cluster_name    = "inferadb-fdb"
  fdb_version     = var.fdb_version
  redundancy_mode = var.fdb_redundancy_mode

  fearless_dr = {
    enabled        = true
    usable_regions = 1
    satellite_logs = var.fdb_satellite_logs
  }

  tailscale = {
    enabled     = true
    auth_key    = var.tailscale_auth_key
    secret_name = "tailscale-auth"
  }

  engine = {
    enabled  = true
    replicas = var.engine_replicas
    image    = var.engine_image
  }

  control = {
    enabled  = true
    replicas = var.control_replicas
    image    = var.control_image
  }

  monitoring = {
    enabled                 = var.enable_monitoring
    create_service_monitors = var.create_service_monitors
  }

  labels = var.labels

  depends_on = [
    module.gke_primary,
    module.gke_dr,
    module.tailscale_acls
  ]
}
