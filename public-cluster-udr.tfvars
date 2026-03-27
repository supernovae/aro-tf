# Greenfield public ARO cluster with User Defined Routing.
# Terraform creates VNet, subnets, and a managed route table.
# Usage: terraform apply -var-file=public-cluster-udr.tfvars

cluster_name        = "publicclusterudr"
location            = "eastus"
resource_group_name = "aro-public-udr-rg"
public_endpoint     = true
enable_udr          = true
worker_node_count   = 3

# Service principal and pull secret — set via environment variables (see README.md step 3):
#   export TF_VAR_service_principal_client_id=...
#   export TF_VAR_service_principal_client_secret=...
#   export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# OpenShift version in X.Y.Z format (list with: az aro get-versions -l eastus -o table)
aro_version = "4.20.15"

# VM sizes
# master_vm_size      = "Standard_D8s_v3"
# worker_vm_size      = "Standard_D4s_v3"

# VNet address space
# vnet_address_space           = "10.0.0.0/22"
# master_subnet_address_prefix = "10.0.0.0/23"
# worker_subnet_address_prefix = "10.0.2.0/23"

# Tags
# environment = "prod"
# tags = {
#   Project = "MyProject"
#   Owner   = "MyTeam"
# }
