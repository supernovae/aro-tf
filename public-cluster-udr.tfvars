# Greenfield public ARO cluster with User Defined Routing.
# Terraform creates VNet, subnets, and a managed route table.
# Usage: terraform apply -var-file=public-cluster-udr.tfvars

cluster_name        = "publicclusterudr"
location            = "eastus"
resource_group_name = "aro-public-udr-rg"
public_endpoint     = true
enable_udr          = true
worker_node_count   = 3

# Service principal — see README.md for setup instructions.
service_principal_client_id     = ""
service_principal_client_secret = ""

# Set pull_secret via env var: export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# Uncomment to pin a specific OpenShift version
# aro_version = "4.15"

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
