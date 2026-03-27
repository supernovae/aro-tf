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

### 3. Create an ARO service principal

ARO requires a dedicated service principal that the cluster uses to manage Azure resources. This is separate from the Terraform authentication credentials.

```bash
# Create the service principal
az ad sp create-for-rbac --name "aro-cluster-sp" --skip-assignment

# Note the appId and password from the output, then export:
export TF_VAR_service_principal_client_id="<appId>"
export TF_VAR_service_principal_client_secret="<password>"
```

The ARO RP service principal (with well-known ID `f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875`) also needs Network Contributor on the VNet. For greenfield deployments, grant this after the first `terraform apply` creates the VNet, or grant it at the resource group scope upfront:

```bash
# Get the ARO RP service principal object ID
ARO_RP_OBJ_ID=$(az ad sp show --id f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --query id -o tsv)

# Grant Network Contributor on the resource group (adjust scope as needed)
az role assignment create \
  --assignee-object-id "$ARO_RP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>
```

Also grant the cluster service principal Network Contributor on the VNet:

```bash
az role assignment create \
  --assignee "$TF_VAR_service_principal_client_id" \
  --role "Network Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>
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
| UDR with custom route table | BYO | Yes (supplied) | [`udr-custom-route-table.tfvars`](udr-custom-route-table.tfvars) |

#### BYO VNet prerequisites

When bringing your own VNet, ensure the master and worker subnets:

- Have service endpoints for `Microsoft.Storage` and `Microsoft.ContainerRegistry`.
- Are sized at least /23 (master) and /23 (worker).
- Do not overlap with `pod_cidr` (default `10.128.0.0/14`) or `service_cidr` (default `172.30.0.0/16`).
- Reside in a region that supports ARO — check with `az aro get-versions -l <region>`.

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
az aro list-credentials --name <CLUSTER_NAME> --resource-group <RESOURCE_GROUP>

# Log in with the oc CLI
API_URL=$(terraform output -raw api_server_url)
CREDS=$(az aro list-credentials --name <CLUSTER_NAME> --resource-group <RESOURCE_GROUP>)
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
| `service_principal_client_id` | Cluster SP client ID | *required* |
| `service_principal_client_secret` | Cluster SP client secret | *required* |
| `aro_version` | OpenShift version (`az aro get-versions`) | `4.15` |
| `public_endpoint` | Public API server and ingress | `true` |
| `enable_udr` | Enable User Defined Routing | `false` |
| `vnet_id` | Existing VNet ID (BYO mode) | `null` |
| `master_subnet_id` | Existing master subnet ID (BYO) | `null` |
| `worker_subnet_id` | Existing worker subnet ID (BYO) | `null` |
| `udr_route_table_id` | Existing route table ID (custom UDR) | `null` |
| `worker_node_count` | Number of worker nodes | `3` |
| `master_vm_size` | Master node VM SKU | `Standard_D8s_v3` |
| `worker_vm_size` | Worker node VM SKU | `Standard_D4s_v3` |

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
├── public-cluster-existing-vnet.tfvars  # BYO VNet public cluster
├── udr-cluster-existing-vnet.tfvars     # BYO VNet + managed UDR
├── udr-custom-route-table.tfvars        # BYO VNet + supplied route table
└── .github/workflows/terraform.yml      # CI: fmt, validate, tfsec
```

## Notes

- ARO cluster creation takes roughly 30–45 minutes.
- The OpenShift version must be one supported in your region. List available versions with `az aro get-versions -l <region> -o table`.
- For production, configure a [remote state backend](backend.example.tf) and store secrets in a vault rather than environment variables.
