"""
Create and run a Foundry prompt agent that routes through the LiteLLM AI gateway.

The only difference from a "normal" Foundry agent is the model deployment name,
which uses the gateway connection: <connection-name>/<model-name>
(for example: litellm-gateway/gpt-5.4-mini).

Usage:
    export FOUNDRY_PROJECT_ENDPOINT="$(terraform -chdir=../terraform output -raw foundry_project_endpoint)"
    export FOUNDRY_MODEL_DEPLOYMENT_NAME="$(terraform -chdir=../terraform output -raw foundry_model_deployment_name)"
    az login
    pip install -r requirements.txt
    python run_agent.py
"""

import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition
from azure.identity import DefaultAzureCredential

project_endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
model_deployment_name = os.environ["FOUNDRY_MODEL_DEPLOYMENT_NAME"]

project = AIProjectClient(
    endpoint=project_endpoint,
    credential=DefaultAzureCredential(),
)

agent = project.agents.create_version(
    agent_name="litellm-gateway-agent",
    definition=PromptAgentDefinition(
        model=model_deployment_name,
        instructions="You are a helpful assistant that answers concisely.",
    ),
)
print(f"Created agent {agent.name} (version {agent.version})")

openai_client = project.get_openai_client()
conversation = openai_client.conversations.create()

response = openai_client.responses.create(
    conversation=conversation.id,
    input="In one sentence, what is an AI gateway?",
    extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}},
)

print("\nAgent response:")
print(response.output_text)
