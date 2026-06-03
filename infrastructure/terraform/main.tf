# Terraform configuration for {{SERVICE_NAME}}
# Primary cloud: {{PRIMARY_CLOUD}} | DR: {{SECONDARY_CLOUD}}

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state — update bucket/container names for your environment
  backend "azurerm" {
    resource_group_name  = "meijer-tfstate-rg"
    storage_account_name = "meijertfstate"
    container_name       = "tfstate"
    key                  = "{{SERVICE_NAME}}.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ─────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────
variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
}

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "gcp_project_id" {
  description = "GCP project ID for DR"
  type        = string
  default     = "meijer-dr"
}

variable "gcp_region" {
  description = "GCP region for DR"
  type        = string
  default     = "us-east1"
}

# ─────────────────────────────────────────────
# Cosmos DB (primary database)
# ─────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "main" {
  count               = var.environment == "production" ? 1 : 0
  name                = "{{SERVICE_NAME}}-cosmos-${var.environment}"
  location            = var.azure_location
  resource_group_name = "meijer-${var.environment}-rg"
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.azure_location
    failover_priority = 0
  }

  tags = {
    service     = "{{SERVICE_NAME}}"
    environment = var.environment
    criticality = "{{CRITICALITY}}"
    managed_by  = "terraform"
  }
}

# ─────────────────────────────────────────────
# Azure Container App (runtime)
# ─────────────────────────────────────────────
resource "azurerm_container_app" "main" {
  name                         = "{{SERVICE_NAME}}-${var.environment}"
  container_app_environment_id = data.azurerm_container_app_environment.meijer.id
  resource_group_name          = "meijer-${var.environment}-rg"
  revision_mode                = "Single"

  template {
    container {
      name   = "{{SERVICE_NAME}}"
      image  = "meijeracr.azurecr.io/{{SERVICE_NAME}}:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  tags = {
    service     = "{{SERVICE_NAME}}"
    environment = var.environment
    criticality = "{{CRITICALITY}}"
    managed_by  = "terraform"
  }
}

data "azurerm_container_app_environment" "meijer" {
  name                = "meijer-${var.environment}-cae"
  resource_group_name = "meijer-${var.environment}-rg"
}

# ─────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────
output "service_url" {
  description = "Container App URL"
  value       = azurerm_container_app.main.latest_revision_fqdn
}
