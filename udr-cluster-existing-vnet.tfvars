# BYO VNet — ARO cluster with UDR on an existing VNet and subnets.
# Terraform creates a managed route table and associates it with the subnets.
# Subnets should have service endpoints for Microsoft.Storage and Microsoft.ContainerRegistry.
# Usage: terraform apply -var-file=udr-cluster-existing-vnet.tfvars

cluster_name        = "existingvnetudrcluster"
location            = "eastus"
resource_group_name = "aro-existing-vnet-udr-rg"
public_endpoint     = true
enable_udr          = true
worker_node_count   = 3

# Replace these with your actual resource IDs
vnet_id          = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"
master_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<master-subnet>"
worker_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<worker-subnet>"

# Service principal and pull secret — set via environment variables (see README.md step 3):
#   export TF_VAR_service_principal_client_id=...
#   export TF_VAR_service_principal_client_secret=...
#   export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# Supply your own route table instead of letting Terraform create one:
# udr_route_table_id = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/routeTables/<rt-name>"

# OpenShift version in X.Y.Z format (list with: az aro get-versions -l eastus -o table)
aro_version = "4.20.15"

# VM sizes
# master_vm_size      = "Standard_D8s_v3"
# worker_vm_size      = "Standard_D4s_v3"

# Tags
# environment = "prod"
# tags = {
#   Project = "MyProject"
#   Owner   = "MyTeam"
# }
