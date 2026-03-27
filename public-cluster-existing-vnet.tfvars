# BYO VNet — public ARO cluster on an existing VNet and subnets.
# Subnets should have service endpoints for Microsoft.Storage and Microsoft.ContainerRegistry.
# Usage: terraform apply -var-file=public-cluster-existing-vnet.tfvars

cluster_name = "existingvnetcluster"
location     = "eastus"
# resource_group_name — set via env var: export TF_VAR_resource_group_name="..." (see README.md step 3)
public_endpoint   = true
enable_udr        = false
worker_node_count = 3

# Replace these with your actual resource IDs
vnet_id          = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"
master_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<master-subnet>"
worker_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<worker-subnet>"

# Required env vars — set before running terraform (see README.md step 3):
#   export TF_VAR_resource_group_name="aro-existing-vnet-rg"
#   export TF_VAR_service_principal_client_id=...
#   export TF_VAR_service_principal_client_secret=...
#   export TF_VAR_service_principal_object_id=$(az ad sp show --id $TF_VAR_service_principal_client_id --query id -o tsv)
#   export TF_VAR_aro_rp_sp_object_id=$(az ad sp show --id f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --query id -o tsv)
#   export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# OpenShift version in X.Y.Z format (list with: az aro get-versions -l eastus -o table)
aro_version = "4.20.15"

# FIPS mode — enable FIPS 140-2 validated cryptographic modules (requires 4.10+, forces new cluster)
# fips_enabled = true

# VM sizes — defaults are Dsv5. For OpenShift 4.19+, Dsv6 is recommended if quota is available.
# master_vm_size      = "Standard_D8s_v5"
# worker_vm_size      = "Standard_D4s_v5"
# master_vm_size      = "Standard_D8s_v6"   # preferred with 4.19+
# worker_vm_size      = "Standard_D4s_v6"   # preferred with 4.19+

# Tags
# environment = "prod"
# tags = {
#   Project = "MyProject"
#   Owner   = "MyTeam"
# }
