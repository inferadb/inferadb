# InferaDB AWS Multi-Region Deployment
# =====================================
# This example deploys InferaDB across two AWS regions with Fearless DR
#
# Architecture:
# - us-west-2: Primary region with EKS + FDB + InferaDB
# - eu-west-1: DR region with EKS + FDB + InferaDB
# - Tailscale: Cross-region mesh networking
# - FDB Fearless DR: Automatic data replication

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
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
  #   key            = "inferadb/multi-region/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# =============================================================================
# Providers
# =============================================================================

# AWS Provider - Primary Region
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# AWS Provider - DR Region
provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

# Kubernetes Providers (configured after EKS is created)
provider "kubernetes" {
  alias = "primary"

  host                   = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_primary.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_primary.cluster_name, "--region", var.primary_region]
  }
}

provider "kubernetes" {
  alias = "dr"

  host                   = module.eks_dr.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_dr.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_dr.cluster_name, "--region", var.dr_region]
  }
}

# Helm Providers
provider "helm" {
  alias = "primary"

  kubernetes {
    host                   = module.eks_primary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_primary.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_primary.cluster_name, "--region", var.primary_region]
    }
  }
}

provider "helm" {
  alias = "dr"

  kubernetes {
    host                   = module.eks_dr.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_dr.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_dr.cluster_name, "--region", var.dr_region]
    }
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

data "aws_availability_zones" "primary" {
  provider = aws.primary
  state    = "available"
}

data "aws_availability_zones" "dr" {
  provider = aws.dr
  state    = "available"
}

# =============================================================================
# VPC - Primary Region
# =============================================================================

module "vpc_primary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.primary
  }

  name = "${var.cluster_name}-primary"
  cidr = var.primary_vpc_cidr

  azs             = slice(data.aws_availability_zones.primary.names, 0, 3)
  private_subnets = [for i in range(3) : cidrsubnet(var.primary_vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.primary_vpc_cidr, 4, i + 3)]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS requirements
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

# =============================================================================
# VPC - DR Region
# =============================================================================

module "vpc_dr" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.dr
  }

  name = "${var.cluster_name}-dr"
  cidr = var.dr_vpc_cidr

  azs             = slice(data.aws_availability_zones.dr.names, 0, 3)
  private_subnets = [for i in range(3) : cidrsubnet(var.dr_vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.dr_vpc_cidr, 4, i + 3)]

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

  tags = var.tags
}

# =============================================================================
# EKS - Primary Region
# =============================================================================

module "eks_primary" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  providers = {
    aws = aws.primary
  }

  cluster_name    = "${var.cluster_name}-primary"
  cluster_version = var.eks_version

  vpc_id     = module.vpc_primary.vpc_id
  subnet_ids = module.vpc_primary.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    # General workloads
    general = {
      name           = "general"
      instance_types = var.general_instance_types
      min_size       = var.general_min_size
      max_size       = var.general_max_size
      desired_size   = var.general_desired_size

      labels = {
        workload = "general"
      }
    }

    # FDB dedicated nodes
    fdb = {
      name           = "fdb"
      instance_types = var.fdb_instance_types
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

  tags = var.tags
}

# =============================================================================
# EKS - DR Region
# =============================================================================

module "eks_dr" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  providers = {
    aws = aws.dr
  }

  cluster_name    = "${var.cluster_name}-dr"
  cluster_version = var.eks_version

  vpc_id     = module.vpc_dr.vpc_id
  subnet_ids = module.vpc_dr.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = var.general_instance_types
      min_size       = var.general_min_size
      max_size       = var.general_max_size
      desired_size   = var.general_desired_size

      labels = {
        workload = "general"
      }
    }

    fdb = {
      name           = "fdb"
      instance_types = var.fdb_instance_types
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

  tags = var.tags
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

  # Enable SSH for debugging (disable in production)
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
        config_context = "eks-${var.cluster_name}-primary"
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

      zones = slice(data.aws_availability_zones.primary.names, 0, 3)
    },
    {
      id         = var.dr_region
      name       = "DR"
      is_primary = false
      priority   = 2
      namespace  = var.namespace

      kubernetes = {
        config_context = "eks-${var.cluster_name}-dr"
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

      zones = slice(data.aws_availability_zones.dr.names, 0, 3)
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

  labels = var.tags

  depends_on = [
    module.eks_primary,
    module.eks_dr,
    module.tailscale_acls
  ]
}
