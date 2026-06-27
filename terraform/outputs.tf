output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "litellm_endpoint" {
  description = "Public base URL of the LiteLLM AI gateway."
  value       = "https://${azurerm_container_app.litellm.ingress[0].fqdn}"
}

output "litellm_master_key" {
  description = "Master key for authenticating to the LiteLLM gateway (also used by the Foundry connection)."
  value       = random_password.litellm_master_key.result
  sensitive   = true
}

output "foundry_project_endpoint" {
  description = "Agents Foundry project endpoint for the agents SDK."
  value       = "https://${local.foundry_agents_name}.services.ai.azure.com/api/projects/${local.foundry_agents_project}"
}

output "foundry_model_deployment_name" {
  description = "Value for FOUNDRY_MODEL_DEPLOYMENT_NAME: <connection-name>/<model-name>."
  value       = "${var.connection_name}/${var.backend_model_name}"
}
