# RAGline Helm Charts

This directory contains Helm charts for deploying RAGline to Kubernetes.

## Quick Start

### Local Development

1. Copy the environment template:
   ```bash
   cp helm.env.template helm.env
   ```

2. Edit `helm.env` with your actual secrets and credentials

3. Install RAGline:
   ```bash
   source helm.env && ./helm-install.sh
   ```

### Production/CI Environment

In production environments (GitHub Actions, CI/CD pipelines), set the environment variables directly and run:

```bash
./helm-install.sh
```

The script will automatically detect if environment variables are set and use them instead of the local `helm.env` file.

## Environment Variables

The following environment variables are required:

### Azure DevOps
- `AZDO_ORG` - Azure DevOps organization URL
- `AZDO_TOKEN` - Azure DevOps personal access token
- `AZURE_DEVOPS_PAT` - Azure DevOps PAT for agent service

### GitHub
- `GITHUB_TOKEN` - GitHub personal access token
- `GITHUB_PAT` - GitHub PAT (same as GITHUB_TOKEN)

### Microsoft 365
- `M365_TENANT_ID` - M365 tenant ID
- `M365_CLIENT_ID` - M365 application client ID
- `M365_CLIENT_SECRET` - M365 application client secret
- `M365_USERNAME` - M365 service account username
- `M365_PASSWORD` - M365 service account password
- `M365_SHAREPOINT_HOST` - SharePoint host
- `M365_SITE_PATH` - SharePoint site path

### OpenAI
- `OPENAI_API_KEY` - OpenAI API key
- `AZURE_OPENAI_API_KEY` - Azure OpenAI API key (optional)
- `AZURE_OPENAI_ENDPOINT` - Azure OpenAI endpoint (optional)

### Entra ID
- `ENTRA_ID_CLIENT_SECRET` - Entra ID client secret

### Container Registry
- `GHCR_USERNAME` - GitHub Container Registry username
- `GHCR_TOKEN` - GitHub Container Registry token

## GitHub Actions Example

```yaml
name: Deploy RAGline
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Kubernetes
      env:
        AZDO_ORG: ${{ secrets.AZDO_ORG }}
        AZDO_TOKEN: ${{ secrets.AZDO_TOKEN }}
        AZURE_DEVOPS_PAT: ${{ secrets.AZURE_DEVOPS_PAT }}
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        GITHUB_PAT: ${{ secrets.GITHUB_PAT }}
        M365_TENANT_ID: ${{ secrets.M365_TENANT_ID }}
        M365_CLIENT_ID: ${{ secrets.M365_CLIENT_ID }}
        M365_CLIENT_SECRET: ${{ secrets.M365_CLIENT_SECRET }}
        M365_USERNAME: ${{ secrets.M365_USERNAME }}
        M365_PASSWORD: ${{ secrets.M365_PASSWORD }}
        M365_SHAREPOINT_HOST: ${{ secrets.M365_SHAREPOINT_HOST }}
        M365_SITE_PATH: ${{ secrets.M365_SITE_PATH }}
        OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        ENTRA_ID_CLIENT_SECRET: ${{ secrets.ENTRA_ID_CLIENT_SECRET }}
        GHCR_USERNAME: ${{ secrets.GHCR_USERNAME }}
        GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
      run: |
        cd ragline-helm
        ./helm-install.sh
```

## Files

- `Chart.yaml` - Helm chart metadata
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes manifest templates
- `helm-install.sh` - Installation script with secret handling
- `helm.env.template` - Environment variables template
- `helm.env` - Local environment variables (gitignored)
- `README.md` - This file

## Security

- The `helm.env` file is automatically gitignored to prevent secrets from being committed
- In production, use your CI/CD system's secret management (GitHub Secrets, etc.)
- Never commit actual secrets to version control