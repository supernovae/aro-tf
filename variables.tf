# =============================================================================
# ARO Cluster Variables
# =============================================================================

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "The name of the ARO cluster"
  type        = string
}

variable "cluster_domain" {
  description = "Custom cluster domain. Defaults to cluster_name if empty."
  type        = string
  default     = ""
}

variable "aro_version" {
  description = "The OpenShift version to deploy in X.Y.Z format (e.g. 4.14.16). Run `az aro get-versions -l <region>` to list supported versions."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.aro_version))
    error_message = "aro_version must be in X.Y.Z format (e.g. 4.14.16). List available versions with: az aro get-versions -l <region> -o table"
  }
}

variable "pull_secret" {
  description = "The Red Hat pull secret for the OpenShift cluster (JSON string)"
  type        = string
  sensitive   = true
}

variable "fips_enabled" {
  description = "Enable FIPS validated cryptographic modules. Changing this forces a new cluster. Requires OpenShift 4.10+."
  type        = bool
  default     = false
}

# =============================================================================
# Service Principal
# =============================================================================

variable "service_principal_client_id" {
  description = "Client ID (appId) of the service principal used by the ARO cluster"
  type        = string
}

variable "service_principal_client_secret" {
  description = "Client secret (password) of the service principal used by the ARO cluster"
  type        = string
  sensitive   = true
}

variable "service_principal_object_id" {
  description = "Object ID of the cluster service principal. Get with: az ad sp show --id <appId> --query id -o tsv"
  type        = string
  default     = null
}

variable "aro_rp_sp_object_id" {
  description = "Object ID of the ARO resource provider service principal. Get with: az ad sp show --id f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --query id -o tsv"
  type        = string
  default     = null
}

variable "manage_role_assignments" {
  description = "Let Terraform create VNet-scoped Network Contributor role assignments for the cluster SP and the ARO RP. Requires Owner or User Access Administrator. Set to false to manage role assignments manually via az CLI."
  type        = bool
  default     = true
}

# =============================================================================
# Location and Resource Group
# =============================================================================

variable "location" {
  description = "The Azure region for the cluster resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "The name of the resource group to create for cluster resources"
  type        = string

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name is required."
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vnet_name" {
  description = "Custom name for the Terraform-managed VNet. Ignored when using BYO VNet (vnet_id is set). Defaults to '<cluster_name>-vnet'."
  type        = string
  default     = ""
}

variable "vnet_id" {
  description = "The resource ID of an existing VNet (BYO VNet mode). Leave null to let Terraform create one."
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "The address space for the Terraform-managed VNet (ignored when using BYO VNet)"
  type        = string
  default     = "10.0.0.0/22"
}

variable "master_subnet_address_prefix" {
  description = "The address prefix for the master subnet (used only when Terraform creates the VNet)"
  type        = string
  default     = "10.0.0.0/23"
}

variable "worker_subnet_address_prefix" {
  description = "The address prefix for the worker subnet (used only when Terraform creates the VNet)"
  type        = string
  default     = "10.0.2.0/23"
}

variable "master_subnet_id" {
  description = "The resource ID of an existing master subnet (required when vnet_id is set)"
  type        = string
  default     = null
}

variable "worker_subnet_id" {
  description = "The resource ID of an existing worker subnet (required when vnet_id is set)"
  type        = string
  default     = null
}

# =============================================================================
# Endpoint Configuration (Public/Private)
# =============================================================================

variable "public_endpoint" {
  description = "Enable public endpoints for API server and ingress"
  type        = bool
  default     = true
}

# =============================================================================
# UDR (User Defined Routing) Configuration
# =============================================================================

variable "enable_udr" {
  description = "Enable User Defined Routing for the cluster"
  type        = bool
  default     = false
}

variable "udr_route_table_id" {
  description = "The resource ID of an existing route table to associate with master/worker subnets. When null and enable_udr is true, Terraform creates one."
  type        = string
  default     = null
}

# =============================================================================
# VM Sizes and Disk Configuration
# =============================================================================

variable "master_vm_size" {
  description = "VM size for master (control plane) nodes. Dsv5 recommended; Dsv6 supported on OpenShift 4.19+."
  type        = string
  default     = "Standard_D8s_v5"
}

variable "worker_vm_size" {
  description = "VM size for worker nodes. Dsv5 recommended; Dsv6 supported on OpenShift 4.19+."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "worker_disk_size_gb" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 128
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

# =============================================================================
# Network Profiles
# =============================================================================

variable "pod_cidr" {
  description = "The CIDR for pod IPs"
  type        = string
  default     = "10.128.0.0/14"
}

variable "service_cidr" {
  description = "The CIDR for service IPs"
  type        = string
  default     = "172.30.0.0/16"
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}
