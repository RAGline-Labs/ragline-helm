# RAGline Helm Charts

This directory contains Helm charts for deploying RAGline to Kubernetes.

## Quick Start

### Local Development

1. If you do not already have `helm.env`, create it from the template (do not overwrite an existing file):
   ```bash
   test -f helm.env || cp helm.env.template helm.env
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

## PVC storage class and `helm upgrade` failures

Kubernetes does not allow changing `PersistentVolumeClaim.spec.storageClassName` after the PVC is created. If `helm upgrade` fails with **Forbidden: spec is immutable** and a diff from `"default"` to `null` (or any class change), you must **delete the PVCs** and upgrade again so Helm recreates them. That **wipes data** on those volumes unless you have snapshots or external backups—use only on empty or disposable clusters.

```bash
kubectl delete pvc ragline-data-pvc llm-models-pvc -n ragline
cd ragline-helm && source helm.env && ./helm-upgrade.sh
```

Or from `ragline-helm` after `source helm.env`:

```bash
RECREATE_DATA_PVCS=1 ./helm-upgrade.sh
```

### After changing `storageClassName` on the release

Helm stores prior `--set` values on the release. If PVCs were created with the wrong class, delete the PVCs (as above), then upgrade with explicit empty classes so new claims omit `storageClassName` and bind to the cluster default (for example `local-path` on k3s):

```bash
helm upgrade ragline . --namespace ragline --reuse-values \
  --set storage.persistentVolume.storageClassName= \
  --set storage.llmModelsPV.storageClassName=
```

## Adjudication service (`adjudication-svc`)

The chart defaults **`services.adjudicationSvc.enabled: false`** because **`ghcr.io/ragline-labs/adjudication-svc`** may not be published yet (`manifest unknown` / `not found`). Build and push with `./scripts/build-service.sh adjudication-svc` (and your registry pipeline), then set **`services.adjudicationSvc.enabled: true`** or `--set services.adjudicationSvc.enabled=true`.

## LLM pod `CrashLoopBackOff` during model load

The LLM Deployment uses a **`startupProbe`** (see `values.yaml` under `services.llmSvc`) so kubelet does not run short global liveness probes while the GGUF is loading. If upgrades interrupt the download job, run **`DELETE_LLM_MODEL_JOB=0 ./helm-upgrade.sh`** until **`ragline-llm-svc-model-init`** completes, or wait for the Job to finish before upgrading.

## GHCR image pull `403` / `ErrImagePull`

If kubelet events show `failed to fetch oauth token ... 403 Forbidden` when pulling `ghcr.io/ragline-labs/...`, the cluster is rejecting registry auth. Typical causes:

- PAT missing **`read:packages`** (and access to the org that owns the images).
- **SSO** not authorized for that PAT on the GitHub org.
- `GHCR_USERNAME` / `GHCR_TOKEN` in `helm.env` out of date or wrong (token must match the user or a bot account that can read the packages).

Re-apply credentials with a fresh `helm upgrade` (or recreate `ghcr-secret` manually) after fixing the token.

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

### Optional: SaaS control plane (`/saas` on agent-svc)

When you want the multi-tenant SaaS APIs and encrypted `service_connections`, set:

- `MONGODB_URI` — MongoDB connection string (control plane and/or data plane; same as Helm `secrets.mongodbUri`)
- `ENCRYPTION_KEY` — Fernet key for encrypting connection secrets (Helm `secrets.encryptionKey`)
- `RAGLINE_SAAS_ENABLED` — `true` or `false` (Helm `config.saas.enabled`; defaults to `true`; set `false` to disable `/saas` handlers)

See [docs/ragline-saas-bootstrap.md](../docs/ragline-saas-bootstrap.md). If `MONGODB_URI` is unset, agent-svc skips SaaS routes and behaves like a single-tenant deploy.

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
        # Optional SaaS:
        # MONGODB_URI: ${{ secrets.MONGODB_URI }}
        # ENCRYPTION_KEY: ${{ secrets.ENCRYPTION_KEY }}
        # RAGLINE_SAAS_ENABLED: "true"
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