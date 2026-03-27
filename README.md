# Azure Red Hat OpenShift (ARO) — Terraform

Deploy an ARO cluster with Terraform. The project supports two deployment paths:

1. **Greenfield** — Terraform creates the resource group, VNet, and subnets.
2. **Bring Your Own VNet (BYO)** — Supply IDs of an existing VNet and subnets; Terraform creates only the cluster and (optionally) a UDR route table.

Both paths support public or private API/ingress endpoints and optional User Defined Routing (UDR).

## Prerequisites

| Requirement | Details |
|---|---|
| Terraform | `>= 1.5` — [install guide](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | `>= 2.40` — [install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Azure subscription | With quota for ARO in the target region |
| Red Hat pull secret | See [Obtain a pull secret](#1-obtain-a-red-hat-pull-secret) below |

### Register required Azure resource providers

ARO needs the `Microsoft.RedHatOpenShift` resource provider (and `Microsoft.Compute`, `Microsoft.Storage`, `Microsoft.Authorization` which are usually registered by default). Register them once per subscription:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

Verify registration:

```bash
az provider show -n Microsoft.RedHatOpenShift -o table
```

## Step-by-step setup

### 1. Obtain a Red Hat pull secret

1. Go to the [Red Hat Hybrid Cloud Console — Pull Secret page](https://console.redhat.com/openshift/install/pull-secret).
2. Log in with (or create) a free Red Hat account.
3. Click **Download pull secret** and save the file (e.g. `pull-secret.txt`).
4. **Never commit this file to git.** The `.gitignore` in this repo already excludes `pull-secret.txt`, but double-check before pushing.

You will pass the pull secret to Terraform as a variable. The recommended approach:

```bash
export TF_VAR_pull_secret="$(cat pull-secret.txt)"
```

### 2. Authenticate Terraform to Azure

#### Interactive (local development)

```bash
az login
```

After logging in, verify which subscription is active:

```bash
az account list -o table
```

If the correct subscription is already marked `IsDefault = True`, you are ready to go — Terraform will use it automatically. Otherwise, switch to the desired subscription:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

You can confirm the active subscription at any time with:

```bash
az account show -o table
```

Terraform's AzureRM provider picks up the CLI session automatically, so no extra configuration is needed for local use.

#### Service principal (CI / automation)

Create a service principal with a role assignment scoped to the subscription (or a resource group if you prefer least-privilege):

```bash
az ad sp create-for-rbac \
  --name "terraform-aro" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

Export the returned values as environment variables:

```bash
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
```

For GitHub Actions with OIDC federated credentials, see [Configuring OpenID Connect in Azure](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).

> **Note:** ARO creation requires Contributor (or equivalent) on the subscription or resource group and the ability to assign the `Microsoft.RedHatOpenShift` resource provider. Consult the [official ARO prerequisites](https://learn.microsoft.com/azure/openshift/tutorial-create-cluster#verify-your-permissions) for the current minimum RBAC requirements.

### 3. Create an ARO service principal and assign roles

ARO requires a dedicated service principal that the cluster uses to manage Azure resources. This is separate from the Terraform authentication credentials.

First, capture your subscription details and set the resource group name. Exporting `TF_VAR_resource_group_name` means Terraform will use the same value automatically — no need to duplicate it in your tfvars file:

```bash
# Use the currently active subscription (or replace with a specific ID)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Set the resource group name — Terraform picks this up via the TF_VAR_ prefix
export TF_VAR_resource_group_name="aro-public-rg"
```

> **Important:** Do **not** create the resource group manually with `az group create` — Terraform manages it. If you already created it outside of Terraform, import it before running apply:
> ```bash
> terraform import azurerm_resource_group.aro /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TF_VAR_resource_group_name
> ```

Create the cluster service principal and capture its credentials:

```bash
SP_JSON=$(az ad sp create-for-rbac --name "aro-cluster-sp" --skip-assignment -o json)
export TF_VAR_service_principal_client_id=$(echo "$SP_JSON" | jq -r .appId)
export TF_VAR_service_principal_client_secret=$(echo "$SP_JSON" | jq -r .password)
```

#### Role assignments — choose Option A or Option B

ARO requires both the cluster SP and the ARO resource provider SP to have **Network Contributor** on the VNet. How you set this up depends on whether the identity running Terraform has **Owner** or **User Access Administrator** permission.

**Option A — Let Terraform manage roles (default, requires Owner or User Access Administrator)**

Export the SP object IDs so Terraform can create the role assignments automatically:

```bash
export TF_VAR_service_principal_object_id=$(az ad sp show \
  --id "$TF_VAR_service_principal_client_id" --query id -o tsv)
export TF_VAR_aro_rp_sp_object_id=$(az ad sp show \
  --id f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --query id -o tsv)
```

For **greenfield** (Terraform-created VNet), that's it. Terraform creates the assignments and waits for propagation automatically.

For **BYO VNet**, you still need to assign roles manually (see Option B below) — Terraform only manages role assignments on VNets it creates.

**Option B — Manage roles manually (Contributor-only Terraform identity)**

If your Terraform identity only has Contributor, set `manage_role_assignments = false` in your tfvars and create the role assignments via CLI before running apply:

```bash
# Get SP object IDs
SP_OBJ_ID=$(az ad sp show --id "$TF_VAR_service_principal_client_id" --query id -o tsv)
ARO_RP_OBJ_ID=$(az ad sp show --id f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --query id -o tsv)
```

For **greenfield**, the VNet doesn't exist yet — run `terraform apply` first (it will create the VNet and skip role assignments), then assign roles on the new VNet and re-run apply:

```bash
VNET_ID=$(terraform output -raw vnet_id)

az role assignment create \
  --assignee-object-id "$ARO_RP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "$VNET_ID"

az role assignment create \
  --assignee-object-id "$SP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "$VNET_ID"

# Wait ~60s for propagation, then re-apply to create the cluster
sleep 60
terraform apply -var-file=<your-scenario>.tfvars
```

For **BYO VNet**, assign roles on the existing VNet before the first apply:

```bash
az role assignment create \
  --assignee-object-id "$ARO_RP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "$TF_VAR_vnet_id"

az role assignment create \
  --assignee-object-id "$SP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "$TF_VAR_vnet_id"
```

### 4. Choose a deployment scenario

Pick the tfvars file that matches your use case and copy it as a starting point:

| Scenario | VNet | UDR | File |
|---|---|---|---|
| Public cluster | New | No | [`public-cluster.tfvars`](public-cluster.tfvars) |
| Private cluster | New | No | [`private-cluster.tfvars`](private-cluster.tfvars) |
| Public cluster + UDR | New | Yes (managed) | [`public-cluster-udr.tfvars`](public-cluster-udr.tfvars) |
| Private cluster + UDR | New | Yes (managed) | [`private-cluster-udr.tfvars`](private-cluster-udr.tfvars) |
| Public cluster on existing VNet | BYO | No | [`public-cluster-existing-vnet.tfvars`](public-cluster-existing-vnet.tfvars) |
| UDR cluster on existing VNet | BYO | Yes (managed) | [`udr-cluster-existing-vnet.tfvars`](udr-cluster-existing-vnet.tfvars) |
| Private cluster + UDR on existing VNet | BYO | Yes (managed) | [`private-cluster-existing-vnet-udr.tfvars`](private-cluster-existing-vnet-udr.tfvars) |
| UDR with custom route table | BYO | Yes (supplied) | [`udr-custom-route-table.tfvars`](udr-custom-route-table.tfvars) |

#### BYO VNet prerequisites

When bringing your own VNet, ensure the master and worker subnets:

- Have service endpoints for `Microsoft.Storage` and `Microsoft.ContainerRegistry`.
- Are sized at least /23 (master) and /23 (worker).
- Do not overlap with `pod_cidr` (default `10.128.0.0/14`) or `service_cidr` (default `172.30.0.0/16`).
- Reside in a region that supports ARO — check with `az aro get-versions -l <region>`.

#### Setting BYO VNet variables from the CLI

Rather than copying long resource IDs by hand, use the Azure CLI to look them up and export as `TF_VAR_` environment variables:

```bash
NETWORK_RG="my-network-rg"     # resource group that contains your VNet
VNET_NAME="my-vnet"            # name of your existing VNet
MASTER_SUBNET="master"         # name of the master subnet
WORKER_SUBNET="worker"         # name of the worker subnet

export TF_VAR_vnet_id=$(az network vnet show \
  --resource-group "$NETWORK_RG" --name "$VNET_NAME" --query id -o tsv)

export TF_VAR_master_subnet_id=$(az network vnet subnet show \
  --resource-group "$NETWORK_RG" --vnet-name "$VNET_NAME" \
  --name "$MASTER_SUBNET" --query id -o tsv)

export TF_VAR_worker_subnet_id=$(az network vnet subnet show \
  --resource-group "$NETWORK_RG" --vnet-name "$VNET_NAME" \
  --name "$WORKER_SUBNET" --query id -o tsv)
```

If you are also supplying your own route table:

```bash
UDR_NAME="my-udr"

export TF_VAR_udr_route_table_id=$(az network route-table show \
  --resource-group "$NETWORK_RG" --name "$UDR_NAME" --query id -o tsv)
```

Verify the values are set:

```bash
echo "VNet:          $TF_VAR_vnet_id"
echo "Master subnet: $TF_VAR_master_subnet_id"
echo "Worker subnet: $TF_VAR_worker_subnet_id"
```

### 5. Initialize, plan, and apply

```bash
# Initialize providers and backend
terraform init

# Preview changes
terraform plan -var-file=public-cluster.tfvars

# Deploy
terraform apply -var-file=public-cluster.tfvars
```

Replace `public-cluster.tfvars` with whichever file you chose in step 4.

For **greenfield** deployments, Terraform automatically creates VNet-scoped Network Contributor role assignments for both the cluster service principal and the ARO RP, then waits 60 seconds for Azure AD propagation before creating the cluster.

For **BYO VNet** deployments, you must assign Network Contributor on the VNet to both service principals before running apply (see [Setting BYO VNet variables from the CLI](#setting-byo-vnet-variables-from-the-cli)).

#### Optional: remote state backend

Copy [`backend.example.tf`](backend.example.tf) to `backend.tf`, uncomment and configure the backend block for Azure Blob Storage (or S3), then re-run `terraform init`.

### 6. Access the cluster

After `terraform apply` completes:

```bash
# Web console URL
terraform output console_url

# API server URL
terraform output api_server_url

# Retrieve admin credentials (not managed by Terraform — use the Azure CLI)
CLUSTER_NAME=$(terraform output -raw cluster_name)
az aro list-credentials --name "$CLUSTER_NAME" --resource-group "$TF_VAR_resource_group_name"

# Log in with the oc CLI
API_URL=$(terraform output -raw api_server_url)
CREDS=$(az aro list-credentials --name "$CLUSTER_NAME" --resource-group "$TF_VAR_resource_group_name")
oc login "$API_URL" \
  -u "$(echo $CREDS | jq -r .kubeadminUsername)" \
  -p "$(echo $CREDS | jq -r .kubeadminPassword)"
```

### 7. Destroy

```bash
terraform destroy -var-file=public-cluster.tfvars
```

## Variables reference

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

### Key variables

| Variable | Description | Default |
|---|---|---|
| `cluster_name` | Name of the ARO cluster | *required* |
| `resource_group_name` | Resource group to create | *required* |
| `location` | Azure region | `eastus` |
| `pull_secret` | Red Hat pull secret (JSON) | *required* |
| `service_principal_client_id` | Cluster SP client ID (appId) | *required* |
| `service_principal_client_secret` | Cluster SP client secret (password) | *required* |
| `service_principal_object_id` | Cluster SP object ID (Option A only) | `null` |
| `aro_rp_sp_object_id` | ARO RP SP object ID (Option A only) | `null` |
| `manage_role_assignments` | Let Terraform create VNet role assignments (requires Owner/UAA) | `true` |
| `aro_version` | OpenShift version in X.Y.Z format (`az aro get-versions`) | *required* |
| `fips_enabled` | Enable FIPS 140-2 validated crypto modules (forces new cluster) | `false` |
| `public_endpoint` | Public API server and ingress | `true` |
| `enable_udr` | Enable User Defined Routing | `false` |
| `vnet_id` | Existing VNet ID (BYO mode) | `null` |
| `master_subnet_id` | Existing master subnet ID (BYO) | `null` |
| `worker_subnet_id` | Existing worker subnet ID (BYO) | `null` |
| `udr_route_table_id` | Existing route table ID (custom UDR) | `null` |
| `worker_node_count` | Number of worker nodes | `3` |
| `master_vm_size` | Master node VM SKU | `Standard_D8s_v5` |
| `worker_vm_size` | Worker node VM SKU | `Standard_D4s_v5` |

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|---|---|
| `cluster_id` | ARO cluster resource ID |
| `cluster_name` | Cluster name |
| `console_url` | OpenShift web console URL |
| `api_server_url` | API server endpoint |
| `api_server_ip` | API server IP address |
| `ingress_ip` | Ingress controller IP address |
| `vnet_id` | VNet used by the cluster |
| `master_subnet_id` | Master subnet ID |
| `worker_subnet_id` | Worker subnet ID |
| `udr_route_table_id` | UDR route table ID (if enabled) |

## Project structure

```
.
├── main.tf                              # Cluster, VNet, UDR resources
├── variables.tf                         # Input variables
├── outputs.tf                           # Output values
├── README.md                            # This file
├── backend.example.tf                   # Remote state backend examples
├── providers.example.tf                 # Alternative auth patterns
├── public-cluster.tfvars                # Greenfield public cluster
├── private-cluster.tfvars               # Greenfield private cluster
├── public-cluster-udr.tfvars            # Greenfield public + UDR
├── private-cluster-udr.tfvars           # Greenfield private + UDR
├── public-cluster-existing-vnet.tfvars           # BYO VNet public cluster
├── private-cluster-existing-vnet-udr.tfvars      # BYO VNet private + UDR
├── udr-cluster-existing-vnet.tfvars              # BYO VNet + managed UDR
├── udr-custom-route-table.tfvars        # BYO VNet + supplied route table
└── .github/workflows/terraform.yml      # CI: fmt, validate, tfsec
```

## Notes

- ARO cluster creation takes roughly 30–45 minutes.
- The OpenShift version must be one supported in your region. List available versions with `az aro get-versions -l <region> -o table`.
- For production, configure a [remote state backend](backend.example.tf) and store secrets in a vault rather than environment variables.
