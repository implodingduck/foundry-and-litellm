###############################################################################
# Foundry instance #2: "agents" — runs agents, brings its own model
#
# This Foundry account/project does NOT host the model. It consumes the model
# living in the "models" Foundry through the LiteLLM gateway via a ModelGateway
# connection (bring your own model).
###############################################################################

resource "azapi_resource" "ai_foundry_agents" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = local.foundry_agents_name
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
      customSubDomainName    = local.foundry_agents_name
      publicNetworkAccess    = "Enabled"
      networkAcls = {
        defaultAction = "Allow"
      }
    }
  }

  tags = local.tags
}

resource "azapi_resource" "ai_foundry_project" {
  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = local.foundry_agents_project
  parent_id                 = azapi_resource.ai_foundry_agents.id
  location                  = azurerm_resource_group.this.location
  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName = "LiteLLM gateway project"
      description = "Foundry project that consumes a model hosted in another Foundry instance through the LiteLLM AI gateway."
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

###############################################################################
# ModelGateway connection: agents project -> LiteLLM
#
# Complex metadata values (the static model list) must be passed as serialized
# JSON strings, matching the Foundry ModelGateway connection schema.
# Because deploymentInPath = "false", Foundry calls {target}/chat/completions
# and selects the model via the request body, which is what LiteLLM expects.
###############################################################################

resource "azapi_resource" "litellm_connection" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name                      = var.connection_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "ModelGateway"
      target        = "https://${azurerm_container_app.litellm.ingress[0].fqdn}"
      authType      = "ApiKey"
      isSharedToAll = false
      credentials = {
        key = random_password.litellm_master_key.result
      }
      metadata = {
        deploymentInPath = "false"
        models           = jsonencode(local.gateway_models)
      }
    }
  }
}

###############################################################################
# Access for the current user to build and run agents in the agents project
###############################################################################

resource "azurerm_role_assignment" "current_user_ai_user" {
  scope                = azapi_resource.ai_foundry_agents.id
  role_definition_name = "Foundry User"
  principal_id         = data.azurerm_client_config.current.object_id
}
