#!/bin/bash

# RAGline Helm Upgrade Script
# This script upgrades RAGline while preserving all secret configurations
#
# Usage:
#   Local development: source helm.env && ./helm-upgrade.sh
#   Production/CI:     ./helm-upgrade.sh (environment variables should be pre-set)

set -e

echo "🔄 Upgrading RAGline using Helm with secret overrides..."

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
    echo "❌ No environment variables found!"
    echo "Please source helm.env or set environment variables before running this script."
    exit 1
fi

# Parse command line arguments
FORCE_IMAGE_PULL=false
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-pull)
            FORCE_IMAGE_PULL=true
            shift
            ;;
        *)
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
    esac
done

# Set image pull policy
if [ "$FORCE_IMAGE_PULL" = true ]; then
    echo "🔄 Forcing image pull (Always)"
    IMAGE_PULL_POLICY="Always"
else
    echo "📦 Using cached images (IfNotPresent)"
    IMAGE_PULL_POLICY="IfNotPresent"
fi

# Delete LLM job if it exists (since Jobs are immutable)
echo "🗑️  Cleaning up LLM model init job if it exists..."
kubectl delete job ragline-llm-svc-model-init -n ragline --ignore-not-found=true

helm upgrade ragline . \
    --namespace ragline \
    --set global.imagePullPolicy="${IMAGE_PULL_POLICY}" \
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
    --set config.auth.entraId.tenantId="${M365_TENANT_ID}" \
    --set config.auth.entraId.clientId="${M365_CLIENT_ID}" \
    --set secrets.ghcrUsername="${GHCR_USERNAME}" \
    --set secrets.ghcrToken="${GHCR_TOKEN}" \
    ${EXTRA_ARGS}

if [ $? -eq 0 ]; then
    echo "✅ RAGline upgraded successfully!"
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
    if [ "$FORCE_IMAGE_PULL" = true ]; then
        echo "🚀 Images were force-pulled and updated to latest versions!"
    fi
else
    echo "❌ Upgrade failed!"
    exit 1
fi

