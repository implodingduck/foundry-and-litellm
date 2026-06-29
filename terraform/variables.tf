variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "location" {
  type    = string
  default = "EastUS2"
}

variable "gh_repo" {
  type        = string
  description = "owner/repo slug used for resource naming and tagging."
}

variable "litellm_image" {
  type        = string
  description = "Container image for the LiteLLM proxy."
  default     = "ghcr.io/berriai/litellm:main-stable"
}

variable "backend_model_name" {
  type        = string
  description = "Model deployed on the Foundry account and proxied by LiteLLM."
  default     = "gpt-5.4-mini"
}

variable "backend_model_version" {
  type        = string
  description = "Model version. Leave empty to let Azure pick the default version for the model."
  default     = "2026-03-17"
}

variable "backend_model_capacity" {
  type        = number
  description = "TPM capacity (in thousands) for the Foundry model deployment."
  default     = 10
}

variable "azure_openai_api_version" {
  type        = string
  description = "Azure OpenAI API version LiteLLM uses to call the Foundry model deployment."
  default     = "2025-04-01-preview"
}

variable "connection_name" {
  type        = string
  description = "Name of the Foundry ModelGateway connection to LiteLLM."
  default     = "litellm-gateway"
}

variable "litellm_log_level" {
  type        = string
  description = "LiteLLM log verbosity (LITELLM_LOG). WARNING emits just the request/response payloads (via the custom logger) plus genuine warnings/errors; set DEBUG for full framework tracing."
  default     = "WARNING"
}
