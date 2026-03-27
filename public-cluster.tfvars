# Greenfield public ARO cluster — Terraform creates VNet and subnets.
# Usage: terraform apply -var-file=public-cluster.tfvars

cluster_name        = "publiccluster"
location            = "eastus"
resource_group_name = "aro-public-rg"
public_endpoint     = true
enable_udr          = false
worker_node_count   = 3

# Service principal and pull secret — set via environment variables (see README.md step 3):
#   export TF_VAR_service_principal_client_id=...
#   export TF_VAR_service_principal_client_secret=...
#   export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# OpenShift version in X.Y.Z format (list with: az aro get-versions -l eastus -o table)
aro_version = "4.20.15"

# VM sizes (defaults shown)
# master_vm_size      = "Standard_D8s_v3"
# worker_vm_size      = "Standard_D4s_v3"
# worker_disk_size_gb = 128

# VNet address space (greenfield only)
# vnet_address_space           = "10.0.0.0/22"
# master_subnet_address_prefix = "10.0.0.0/23"
# worker_subnet_address_prefix = "10.0.2.0/23"

# Tags
# environment = "prod"
# tags = {
#   Project = "MyProject"
#   Owner   = "MyTeam"
# }
