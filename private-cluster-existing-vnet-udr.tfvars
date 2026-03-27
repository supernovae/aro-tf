# BYO VNet — private ARO cluster with UDR on an existing VNet and subnets.
# API server and ingress are private (not internet-reachable).
# Terraform creates a managed route table and associates it with the subnets.
# Subnets should have service endpoints for Microsoft.Storage and Microsoft.ContainerRegistry.
# Usage: terraform apply -var-file=private-cluster-existing-vnet-udr.tfvars

cluster_name      = "privatebyo"
location          = "eastus"
public_endpoint   = false
enable_udr        = true
worker_node_count = 3

# BYO VNet — set these via TF_VAR_ env vars so they match your infrastructure:
#
#   # Look up your existing resources
#   NETWORK_RG="my-network-rg"
#   VNET_NAME="my-vnet"
#
#   export TF_VAR_vnet_id=$(az network vnet show \
#     --resource-group "$NETWORK_RG" --name "$VNET_NAME" --query id -o tsv)
#
#   export TF_VAR_master_subnet_id=$(az network vnet subnet show \
#     --resource-group "$NETWORK_RG" --vnet-name "$VNET_NAME" --name "master" --query id -o tsv)
#
#   export TF_VAR_worker_subnet_id=$(az network vnet subnet show \
#     --resource-group "$NETWORK_RG" --vnet-name "$VNET_NAME" --name "worker" --query id -o tsv)
#
# Or set them directly:
vnet_id          = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"
master_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<master-subnet>"
worker_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<worker-subnet>"

# Optional: supply your own route table instead of letting Terraform create one:
# export TF_VAR_udr_route_table_id=$(az network route-table show \
#   --resource-group "$NETWORK_RG" --name "my-udr" --query id -o tsv)

# Required env vars — set before running terraform (see README.md step 3):
#   export TF_VAR_resource_group_name="aro-private-byo-udr-rg"
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
# worker_disk_size_gb = 128

# Tags
# environment = "prod"
# tags = {
#   Project = "MyProject"
#   Owner   = "MyTeam"
# }
