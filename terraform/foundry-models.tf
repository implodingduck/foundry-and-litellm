###############################################################################
# Foundry instance #1: "models" — hosts the actual model
#
# This Foundry account hosts the gpt model deployment. It has local auth
# disabled, so the only way in is Entra ID. LiteLLM reaches it with its
# user-assigned managed identity (see litellm.tf).
###############################################################################

resource "azapi_resource" "ai_foundry_models" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = local.foundry_models_name
  parent_id                 = azurerm_resource_group.this.id
  location                  = azurerm_resource_group.this.location
  schema_validation_enabled = false

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = local.foundry_models_name
      disableLocalAuth       = true
      publicNetworkAccess    = "Enabled"
      networkAcls = {
        defaultAction = "Allow"
      }
    }
  }

  tags = local.tags
}

# Project on the models account — not required to serve the model, but makes it
# easy to browse the deployment in the Foundry portal during demos.
resource "azapi_resource" "ai_foundry_models_project" {
  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = local.foundry_models_project
  parent_id                 = azapi_resource.ai_foundry_models.id
  location                  = azurerm_resource_group.this.location
  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName = "Model host project"
      description = "Hosts the model deployment served to other Foundry instances through the LiteLLM gateway."
    }
  }
}

# The model deployment that LiteLLM proxies to.
resource "azurerm_cognitive_deployment" "model" {
  name                 = var.backend_model_name
  cognitive_account_id = azapi_resource.ai_foundry_models.id

  model {
    format  = "OpenAI"
    name    = var.backend_model_name
    version = var.backend_model_version != "" ? var.backend_model_version : null
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.backend_model_capacity
  }
}
