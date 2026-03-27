# =============================================================================
# ARO (Azure Red Hat OpenShift) Cluster Deployment
# =============================================================================
# This module deploys an ARO cluster with support for:
# - Public and private clusters
# - User Defined Routing (UDR)
# - Bring your own VNet or let Terraform create one
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.89"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "aro" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# =============================================================================
# Network Configuration
# =============================================================================

locals {
  # BYO VNet when the caller supplies an existing vnet_id.
  # Greenfield (Terraform creates the VNet) when vnet_id is omitted.
  create_vnet      = var.vnet_id == null
  vnet_id          = local.create_vnet ? azurerm_virtual_network.aro[0].id : var.vnet_id
  master_subnet_id = local.create_vnet ? azurerm_subnet.master[0].id : var.master_subnet_id
  worker_subnet_id = local.create_vnet ? azurerm_subnet.worker[0].id : var.worker_subnet_id
}

resource "azurerm_virtual_network" "aro" {
  count = local.create_vnet ? 1 : 0

  name                = coalesce(var.vnet_name, "${var.cluster_name}-vnet")
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
  address_space       = [var.vnet_address_space]

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "azurerm_subnet" "master" {
  count = local.create_vnet ? 1 : 0

  name                 = "master"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro[0].name
  address_prefixes     = [var.master_subnet_address_prefix]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "worker" {
  count = local.create_vnet ? 1 : 0

  name                 = "worker"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro[0].name
  address_prefixes     = [var.worker_subnet_address_prefix]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

# =============================================================================
# VNet Role Assignments (greenfield + manage_role_assignments = true)
# =============================================================================
# ARO validates that both the cluster SP and the ARO RP have Network
# Contributor on the VNet before creating the cluster. When
# manage_role_assignments = true (default), Terraform handles this.
# Set manage_role_assignments = false if your Terraform identity lacks
# Owner / User Access Administrator — then assign the roles manually
# via az CLI before running apply (see README.md step 3).

locals {
  manage_roles = var.manage_role_assignments && local.create_vnet
}

resource "azurerm_role_assignment" "cluster_sp_network_contributor" {
  count = local.manage_roles ? 1 : 0

  scope                            = local.vnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = var.service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aro_rp_network_contributor" {
  count = local.manage_roles ? 1 : 0

  scope                            = local.vnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = var.aro_rp_sp_object_id
  skip_service_principal_aad_check = true
}

resource "time_sleep" "wait_for_role_propagation" {
  count = local.manage_roles ? 1 : 0

  depends_on = [
    azurerm_role_assignment.cluster_sp_network_contributor,
    azurerm_role_assignment.aro_rp_network_contributor,
  ]

  create_duration = "60s"
}

# =============================================================================
# UDR (User Defined Routing) Configuration
# =============================================================================

locals {
  # Whether Terraform should create a managed route table
  create_route_table = var.enable_udr && var.udr_route_table_id == null && local.create_vnet

  # Whether to associate a route table with subnets managed by this config
  associate_route_table = var.enable_udr && local.create_vnet

  # Effective route table ID — created by us, or supplied by the caller
  effective_route_table_id = local.create_route_table ? azurerm_route_table.udr[0].id : var.udr_route_table_id
}

resource "azurerm_route_table" "udr" {
  count = local.create_route_table ? 1 : 0

  name                = "${var.cluster_name}-udr"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name

  route {
    name           = "to-internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "azurerm_subnet_route_table_association" "master_udr" {
  count = local.associate_route_table ? 1 : 0

  subnet_id      = local.master_subnet_id
  route_table_id = local.effective_route_table_id
}

resource "azurerm_subnet_route_table_association" "worker_udr" {
  count = local.associate_route_table ? 1 : 0

  subnet_id      = local.worker_subnet_id
  route_table_id = local.effective_route_table_id
}

# =============================================================================
# ARO Cluster
# =============================================================================

resource "azurerm_redhat_openshift_cluster" "aro" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name

  depends_on = [time_sleep.wait_for_role_propagation]

  cluster_profile {
    domain       = var.cluster_domain != "" ? var.cluster_domain : var.cluster_name
    pull_secret  = var.pull_secret
    version      = var.aro_version
    fips_enabled = var.fips_enabled
  }

  network_profile {
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
  }

  main_profile {
    vm_size   = var.master_vm_size
    subnet_id = local.master_subnet_id
  }

  worker_profile {
    vm_size      = var.worker_vm_size
    disk_size_gb = var.worker_disk_size_gb
    node_count   = var.worker_node_count
    subnet_id    = local.worker_subnet_id
  }

  api_server_profile {
    visibility = var.public_endpoint ? "Public" : "Private"
  }

  ingress_profile {
    visibility = var.public_endpoint ? "Public" : "Private"
  }

  service_principal {
    client_id     = var.service_principal_client_id
    client_secret = var.service_principal_client_secret
  }

  tags = merge(var.tags, {
    Environment = var.environment
  })

  lifecycle {
    precondition {
      condition     = var.vnet_id == null || (var.master_subnet_id != null && var.worker_subnet_id != null)
      error_message = "When using BYO VNet (vnet_id is set), both master_subnet_id and worker_subnet_id must also be provided."
    }
  }
}
