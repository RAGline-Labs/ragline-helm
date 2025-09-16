#!/bin/bash

# RAGline Helm Installation Script
# This script installs RAGline with all the necessary secret overrides
#
# Usage:
#   Local development: source helm.env && ./helm-install.sh
#   Production/CI:     ./helm-install.sh (environment variables should be pre-set)

set -e

echo "🚀 Installing RAGline using Helm with secret overrides..."

# Optional: Source local environment file if it exists and no secrets are set
if [ -f "helm.env" ] && [ -z "$AZDO_ORG" ]; then
    echo "📁 Sourcing local helm.env file..."
    source helm.env
fi

# Check if we have environment variables or fall back to backup files
if [ -n "$AZDO_ORG" ]; then
    echo "🔐 Using environment variables for secrets..."
    
    # Use environment variables directly
    AZURE_DEVOPS_PAT="${AZURE_DEVOPS_PAT}"
    GITHUB_PAT="${GITHUB_PAT}"
    OPENAI_API_KEY="${OPENAI_API_KEY}"
    AZURE_OPENAI_API_KEY="${AZURE_OPENAI_API_KEY:-}"
    AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT:-}"
    M365_TENANT_ID="${M365_TENANT_ID}"
    M365_CLIENT_ID="${M365_CLIENT_ID}"
    M365_CLIENT_SECRET="${M365_CLIENT_SECRET}"
    M365_USERNAME="${M365_USERNAME}"
    M365_PASSWORD="${M365_PASSWORD}"
    M365_SHAREPOINT_HOST="${M365_SHAREPOINT_HOST}"
    M365_SITE_PATH="${M365_SITE_PATH}"
    AZDO_ORG="${AZDO_ORG}"
    AZDO_TOKEN="${AZDO_TOKEN}"
    GITHUB_TOKEN="${GITHUB_TOKEN}"
    ENTRA_CLIENT_SECRET="${ENTRA_ID_CLIENT_SECRET}"
    GHCR_USERNAME="${GHCR_USERNAME:-}"
    GHCR_TOKEN="${GHCR_TOKEN:-}"
    
else
    echo "🔐 Loading secrets from backup YAML files..."
    
    # Load and decode secrets from backup YAMLs (base64 -> raw)
    BACKUP_DIR="/Users/vtruong/ragline-website/k8s-backup/secrets"

    decode_key() {
      local file="$1"; shift
      local key="$1"; shift
      local b64
      b64=$(awk -v k="$key" 'tolower($0) ~ /data:/ {ind=1; next} ind && $1==k":" {print $2; exit}' "$file")
      if [ -n "$b64" ]; then
        printf "%s" "$b64" | base64 -d 2>/dev/null || true
      fi
    }

    RAGLINE_SECRETS="$BACKUP_DIR/ragline-secrets.yaml"
    MCP_SECRETS="$BACKUP_DIR/ragline-mcp-secrets.yaml"
    ENTRA_SECRET="$BACKUP_DIR/ragline-entra-secret.yaml"

    AZURE_DEVOPS_PAT="$(decode_key "$RAGLINE_SECRETS" AZURE_DEVOPS_PAT)"
    GITHUB_PAT="$(decode_key "$RAGLINE_SECRETS" GITHUB_PAT)"
    OPENAI_API_KEY="$(decode_key "$RAGLINE_SECRETS" OPENAI_API_KEY)"
    AZURE_OPENAI_API_KEY="$(decode_key "$RAGLINE_SECRETS" AZURE_OPENAI_API_KEY)"
    AZURE_OPENAI_ENDPOINT="$(decode_key "$RAGLINE_SECRETS" AZURE_OPENAI_ENDPOINT)"
    M365_TENANT_ID="$(decode_key "$RAGLINE_SECRETS" M365_TENANT_ID)"
    M365_CLIENT_ID="$(decode_key "$RAGLINE_SECRETS" M365_CLIENT_ID)"
    M365_CLIENT_SECRET="$(decode_key "$RAGLINE_SECRETS" M365_CLIENT_SECRET)"
    M365_USERNAME="$(decode_key "$RAGLINE_SECRETS" M365_USERNAME)"
    M365_PASSWORD="$(decode_key "$RAGLINE_SECRETS" M365_PASSWORD)"
    M365_SHAREPOINT_HOST="$(decode_key "$RAGLINE_SECRETS" M365_SHAREPOINT_HOST)"
    M365_SITE_PATH="$(decode_key "$RAGLINE_SECRETS" M365_SITE_PATH)"

    AZDO_ORG="$(decode_key "$MCP_SECRETS" AZDO_ORG)"
    AZDO_TOKEN="$(decode_key "$MCP_SECRETS" AZDO_TOKEN)"
    GITHUB_TOKEN="$(decode_key "$MCP_SECRETS" GITHUB_TOKEN)"

    ENTRA_CLIENT_SECRET="$(decode_key "$ENTRA_SECRET" client-secret)"
fi

helm install ragline . \
    --namespace ragline \
    --create-namespace \
    --set secrets.azureDevOpsPat="${AZURE_DEVOPS_PAT}" \
    --set secrets.githubPat="${GITHUB_PAT}" \
    --set secrets.azureDevOpsOrg="${AZDO_ORG}" \
    --set secrets.azureDevOpsToken="${AZDO_TOKEN}" \
    --set secrets.githubToken="${GITHUB_TOKEN}" \
    --set secrets.m365TenantId="${M365_TENANT_ID}" \
    --set secrets.m365ClientId="${M365_CLIENT_ID}" \
    --set secrets.m365ClientSecret="${M365_CLIENT_SECRET}" \
    --set secrets.m365Username="${M365_USERNAME}" \
    --set secrets.m365Password="${M365_PASSWORD}" \
    --set secrets.m365SharepointHost="${M365_SHAREPOINT_HOST}" \
    --set secrets.m365SitePath="${M365_SITE_PATH}" \
    --set secrets.openaiApiKey="${OPENAI_API_KEY}" \
    --set secrets.azureOpenaiApiKey="${AZURE_OPENAI_API_KEY}" \
    --set secrets.azureOpenaiEndpoint="${AZURE_OPENAI_ENDPOINT}" \
    --set secrets.entraIdClientSecret="${ENTRA_CLIENT_SECRET}" \
    --set secrets.ghcrUsername="${GHCR_USERNAME}" \
    --set secrets.ghcrToken="${GHCR_TOKEN}"

if [ $? -eq 0 ]; then
    echo "✅ RAGline installed successfully!"
    echo ""
    echo "📊 Checking deployment status..."
    kubectl get pods -n ragline
    echo ""
    echo "🌐 Services:"
    kubectl get services -n ragline
    echo ""
    echo "📈 To monitor the deployment:"
    echo "  kubectl get pods -n ragline -w"
    echo ""
    echo "🔍 To view logs:"
    echo "  kubectl logs -n ragline -l app=ragline-chat-ui"
    echo "  kubectl logs -n ragline -l app=ragline-agent-svc"
    echo ""
    echo "🚪 To access the UI (if using minikube):"
    echo "  minikube service ragline-chat-ui-service -n ragline"
else
    echo "❌ Installation failed!"
    exit 1
fi

