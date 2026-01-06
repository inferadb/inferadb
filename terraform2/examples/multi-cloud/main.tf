# InferaDB Multi-Cloud Deployment (AWS + GCP)
# ============================================
# This example deploys InferaDB across AWS and GCP with Fearless DR
#
# Architecture:
# - AWS us-west-2: Primary region with EKS + FDB + InferaDB
# - GCP europe-west1: DR region with GKE + FDB + InferaDB
# - Tailscale: Cross-cloud mesh networking
# - FDB Fearless DR: Automatic data replication

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
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
  # backend "s3" {
  #   bucket         = "your-terraform-state"
  #   key            = "inferadb/multi-cloud/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# =============================================================================
# Providers - AWS
# =============================================================================

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  alias = "aws"

  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  alias = "aws"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

# =============================================================================
# Providers - GCP
# =============================================================================

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  alias = "gcp"

  host                   = "https://${module.gke.endpoint}"
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  alias = "gcp"

  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

# =============================================================================
# Tailscale Provider
# =============================================================================

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "google_compute_zones" "available" {
  region = var.gcp_region
}

# =============================================================================
# AWS VPC
# =============================================================================

module "vpc_aws" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-aws"
  cidr = var.aws_vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for i in range(3) : cidrsubnet(var.aws_vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.aws_vpc_cidr, 4, i + 3)]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.aws_tags
}

# =============================================================================
# AWS EKS
# =============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.cluster_name}-aws"
  cluster_version = var.eks_version

  vpc_id     = module.vpc_aws.vpc_id
  subnet_ids = module.vpc_aws.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = var.aws_general_instance_types
      min_size       = var.general_min_size
      max_size       = var.general_max_size
      desired_size   = var.general_desired_size

      labels = {
        workload = "general"
      }
    }

    fdb = {
      name           = "fdb"
      instance_types = var.aws_fdb_instance_types
      min_size       = var.fdb_node_count
      max_size       = var.fdb_node_count
      desired_size   = var.fdb_node_count

      labels = {
        workload = "fdb"
      }

      taints = [
        {
          key    = "dedicated"
          value  = "fdb"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  tags = var.aws_tags
}

# =============================================================================
# GCP VPC
# =============================================================================

module "vpc_gcp" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.gcp_project_id
  network_name = "${var.cluster_name}-gcp"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name   = "${var.cluster_name}-gcp-nodes"
      subnet_ip     = var.gcp_subnet_cidr
      subnet_region = var.gcp_region
    }
  ]

  secondary_ranges = {
    "${var.cluster_name}-gcp-nodes" = [
      {
        range_name    = "pods"
        ip_cidr_range = var.gcp_pods_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = var.gcp_services_cidr
      }
    ]
  }
}

# =============================================================================
# GCP Cloud Router & NAT
# =============================================================================

resource "google_compute_router" "gcp" {
  name    = "${var.cluster_name}-gcp-router"
  project = var.gcp_project_id
  region  = var.gcp_region
  network = module.vpc_gcp.network_id
}

resource "google_compute_router_nat" "gcp" {
  name                               = "${var.cluster_name}-gcp-nat"
  project                            = var.gcp_project_id
  router                             = google_compute_router.gcp.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# =============================================================================
# GCP GKE
# =============================================================================

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 30.0"

  project_id = var.gcp_project_id
  name       = "${var.cluster_name}-gcp"
  region     = var.gcp_region
  zones      = slice(data.google_compute_zones.available.names, 0, 3)

  network           = module.vpc_gcp.network_name
  subnetwork        = "${var.cluster_name}-gcp-nodes"
  ip_range_pods     = "pods"
  ip_range_services = "services"

  release_channel           = "REGULAR"
  workload_identity_enabled = true
  network_policy            = true

  node_pools = [
    {
      name          = "general"
      machine_type  = var.gcp_general_machine_type
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
      machine_type    = var.gcp_fdb_machine_type
      min_count       = var.fdb_node_count
      max_count       = var.fdb_node_count
      initial_count   = var.fdb_node_count
      disk_size_gb    = 200
      disk_type       = "pd-ssd"
      local_ssd_count = var.gcp_fdb_local_ssd_count
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

  depends_on = [module.vpc_gcp]
}

# =============================================================================
# Tailscale ACLs
# =============================================================================

module "tailscale_acls" {
  source = "../../modules/tailscale-acls"

  tailnet = var.tailscale_tailnet
  api_key = var.tailscale_api_key

  regions = [
    { id = "aws-${var.aws_region}", name = "AWS Primary (${var.aws_region})" },
    { id = "gcp-${var.gcp_region}", name = "GCP DR (${var.gcp_region})" }
  ]

  enable_ssh        = var.enable_ssh
  ssh_allowed_users = var.ssh_allowed_users
}

# =============================================================================
# InferaDB Multi-Cloud Deployment
# =============================================================================

module "inferadb" {
  source = "../../modules/multi-region"

  providers = {
    kubernetes = kubernetes.aws
    helm       = helm.aws
  }

  regions = [
    {
      id         = "aws-${var.aws_region}"
      name       = "AWS Primary"
      is_primary = true
      priority   = 1
      namespace  = var.namespace

      kubernetes = {
        config_context = "eks-${var.cluster_name}-aws"
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

      zones = slice(data.aws_availability_zones.available.names, 0, 3)
    },
    {
      id         = "gcp-${var.gcp_region}"
      name       = "GCP DR"
      is_primary = false
      priority   = 2
      namespace  = var.namespace

      kubernetes = {
        config_context = "gke_${var.gcp_project_id}_${var.gcp_region}_${var.cluster_name}-gcp"
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

      zones = slice(data.google_compute_zones.available.names, 0, 3)
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

  labels = {
    project     = "inferadb"
    environment = "production"
    managed_by  = "terraform"
    deployment  = "multi-cloud"
  }

  depends_on = [
    module.eks,
    module.gke,
    module.tailscale_acls
  ]
}
