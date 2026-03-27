# Greenfield private ARO cluster — Terraform creates VNet and subnets.
# API server and ingress are private (not internet-reachable).
# Usage: terraform apply -var-file=private-cluster.tfvars

cluster_name        = "privatecluster"
location            = "eastus"
resource_group_name = "aro-private-rg"
public_endpoint     = false
enable_udr          = false
worker_node_count   = 3

# Service principal — see README.md for setup instructions.
# Prefer env vars: export TF_VAR_service_principal_client_id=... TF_VAR_service_principal_client_secret=...
service_principal_client_id     = ""
service_principal_client_secret = ""

# Set pull_secret via env var: export TF_VAR_pull_secret="$(cat pull-secret.txt)"

# Uncomment to pin a specific OpenShift version
# aro_version = "4.15"

# VM sizes
# master_vm_size      = "Standard_D8s_v3"
# worker_vm_size      = "Standard_D4s_v3"
# worker_disk_size_gb = 128

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
