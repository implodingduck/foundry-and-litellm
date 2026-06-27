###############################################################################
# Managed identity for the LiteLLM gateway
#
# LiteLLM authenticates to the model hosted in the "models" Foundry instance
# with this user-assigned identity (Entra ID) instead of an account key.
# The model deployment lives on the "models" Foundry account (foundry-models.tf).
###############################################################################

resource "azurerm_user_assigned_identity" "litellm" {
  name                = "uai-litellm-${local.func_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = local.tags
}

# Allow LiteLLM's identity to run inference against the "models" Foundry account.
resource "azurerm_role_assignment" "litellm_foundry_openai_user" {
  scope                = azapi_resource.ai_foundry_models.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.litellm.principal_id
}

###############################################################################
# LiteLLM AI gateway on Azure Container Apps
###############################################################################

resource "azurerm_container_app_environment" "this" {
  name                       = "ace-${local.func_name}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  tags = local.tags
}

resource "azurerm_container_app" "litellm" {
  depends_on = [azurerm_role_assignment.litellm_foundry_openai_user]

  name                         = "aca-litellm-${local.func_name}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.litellm.id]
  }

  secret {
    name  = "litellm-master-key"
    value = random_password.litellm_master_key.result
  }

  secret {
    name = "litellm-config"
    value = templatefile("${path.module}/config/litellm-config.yaml.tftpl", {
      model_name      = var.backend_model_name
      deployment_name = azurerm_cognitive_deployment.model.name
    })
  }

  template {
    # Secret volume: every container app secret is projected as a file named
    # after the secret. LiteLLM reads /etc/litellm/litellm-config.
    volume {
      name         = "config"
      storage_type = "Secret"
    }

    container {
      name   = "litellm"
      image  = var.litellm_image
      cpu    = 1.0
      memory = "2Gi"

      args = ["--config", "/etc/litellm/litellm-config", "--port", "4000"]

      volume_mounts {
        name = "config"
        path = "/etc/litellm"
      }

      env {
        name  = "AZURE_API_BASE"
        value = "https://${local.foundry_models_name}.openai.azure.com"
      }

      env {
        name  = "AZURE_API_VERSION"
        value = var.azure_openai_api_version
      }

      # Log level for the proxy. DEBUG logs each request/response.
      env {
        name  = "LITELLM_LOG"
        value = var.litellm_log_level
      }

      # Tells LiteLLM's DefaultAzureCredential to use this user-assigned
      # managed identity when fetching Entra tokens for the backend.
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.litellm.client_id
      }

      env {
        name        = "LITELLM_MASTER_KEY"
        secret_name = "litellm-master-key"
      }

      startup_probe {
        transport               = "HTTP"
        path                    = "/health/liveliness"
        port                    = 4000
        initial_delay           = 5
        interval_seconds        = 5
        failure_count_threshold = 30
        timeout                 = 60
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health/liveliness"
        port                    = 4000
        initial_delay           = 30
        interval_seconds        = 15
        failure_count_threshold = 30
        timeout                 = 60
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/health/readiness"
        port                    = 4000
        initial_delay           = 10
        interval_seconds        = 10
        failure_count_threshold = 30
        timeout                 = 60
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 4000
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.tags
}
