#!/bin/bash

# RAGline Helm Installation Script
# This script installs RAGline with all the necessary secret overrides
#
# Usage:
#   Local development: source helm.env && ./helm-install.sh
#   Production/CI:     ./helm-install.sh (environment variables should be pre-set)

set -e

HELM_NAMESPACE="${HELM_NAMESPACE:-ragline}"
HELM_RELEASE="${HELM_RELEASE:-ragline}"

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
    MONGODB_URI="${MONGODB_URI:-}"
    ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
    RAGLINE_SAAS_ENABLED="${RAGLINE_SAAS_ENABLED:-true}"
    
else
    echo "No AZDO_ORG in environment and helm.env was not sourced."
    echo "Copy ragline-helm/helm.env.template to ragline-helm/helm.env, fill secrets, then:"
    echo "  cd ragline-helm && source helm.env && ./helm-install.sh"
    echo "Or set the same variables in your CI environment."
    exit 1
fi

helm install "$HELM_RELEASE" . \
    --namespace "$HELM_NAMESPACE" \
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
    --set secrets.ghcrToken="${GHCR_TOKEN}" \
    --set secrets.mongodbUri="${MONGODB_URI:-}" \
    --set secrets.encryptionKey="${ENCRYPTION_KEY:-}" \
    --set config.saas.enabled="${RAGLINE_SAAS_ENABLED:-true}"

if [ $? -eq 0 ]; then
    echo "✅ RAGline installed successfully!"
    echo ""
    echo "📊 Checking deployment status..."
    kubectl get pods -n "$HELM_NAMESPACE"
    echo ""
    echo "🌐 Services:"
    kubectl get services -n "$HELM_NAMESPACE"
    echo ""
    echo "📈 To monitor the deployment:"
    echo "  kubectl get pods -n $HELM_NAMESPACE -w"
    echo ""
    echo "🔍 To view logs:"
    echo "  kubectl logs -n $HELM_NAMESPACE -l app=ragline-chat-ui"
    echo "  kubectl logs -n $HELM_NAMESPACE -l app=ragline-agent-svc"
    echo ""
    echo "🚪 To access the UI (if using minikube):"
    echo "  minikube service ragline-chat-ui-service -n $HELM_NAMESPACE"
else
    echo "❌ Installation failed!"
    exit 1
fi

