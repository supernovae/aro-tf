# =============================================================================
# Provider Authentication Examples
# =============================================================================
# Copy the block you need into a new file (e.g. providers.tf) or set the
# equivalent ARM_* environment variables — the AzureRM provider reads them
# automatically without any provider block changes.
#
# Environment variable approach (preferred for CI):
#   export ARM_CLIENT_ID="<appId>"
#   export ARM_CLIENT_SECRET="<password>"
#   export ARM_TENANT_ID="<tenantId>"
#   export ARM_SUBSCRIPTION_ID="<subscriptionId>"
# =============================================================================

# --- Service Principal (client secret) ---
# provider "azurerm" {
#   features {}
#   client_id       = var.client_id
#   client_secret   = var.client_secret
#   tenant_id       = var.tenant_id
#   subscription_id = var.subscription_id
# }

# --- Managed Identity (Azure-hosted runners / VMs) ---
# provider "azurerm" {
#   features {}
#   use_msi   = true
#   client_id = var.client_id  # optional: specific user-assigned identity
# }

# --- Azure CLI (local development — default in main.tf) ---
# provider "azurerm" {
#   features {}
# }
