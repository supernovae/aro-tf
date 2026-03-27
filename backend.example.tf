# =============================================================================
# ARO Terraform Project - Backend Configuration
# =============================================================================

# Example backend configuration for remote state storage
# Uncomment and configure the backend you want to use

# -----------------------------------------------------------------------------
# Azure Blob Storage Backend (Recommended for production)
# -----------------------------------------------------------------------------
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "tfstate-rg"
#     storage_account_name = "tfstateaccount"
#     container_name       = "tfstate"
#     key                  = "aro/terraform.tfstate"
#   }
# }

# -----------------------------------------------------------------------------
# AWS S3 Backend
# -----------------------------------------------------------------------------
# terraform {
#   backend "s3" {
#     bucket         = "my-tfstate-bucket"
#     key            = "aro/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "tfstate-lock"
#   }
# }

# -----------------------------------------------------------------------------
# Local Backend (Development only)
# -----------------------------------------------------------------------------
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
