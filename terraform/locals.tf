locals {
  func_name      = "fll${random_string.unique.result}"
  loc_for_naming = lower(replace(var.location, " ", ""))
  loc_short      = upper("${substr(local.loc_for_naming, 0, 1)}${trimprefix(trimprefix(local.loc_for_naming, "east"), "west")}")
  gh_repo        = split("/", var.gh_repo)[1]

  # Two Foundry instances:
  #  - "models"  hosts the actual model deployment (LiteLLM proxies to it).
  #  - "agents"  runs agents and connects to the model through LiteLLM (BYOM).
  foundry_models_name    = "aifmdl${local.func_name}"
  foundry_models_project = "projmdl${local.func_name}"
  foundry_agents_name    = "aifsample${local.func_name}"
  foundry_agents_project = "proj${local.func_name}"

  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }

  # Models exposed by the LiteLLM gateway. Each entry must match a model_name in
  # the LiteLLM config (config/litellm-config.yaml.tftpl) and is advertised to
  # Foundry through the ModelGateway connection's static model list.
  gateway_models = [
    {
      name = var.backend_model_name
      properties = {
        model = {
          name    = var.backend_model_name
          version = var.backend_model_version
          format  = "OpenAI"
        }
      }
    }
  ]
}
