# Homelab Setup

ArgoCD App-of-Apps GitOps repository for a single-node Kubernetes homelab cluster.

## Architecture

Three-layer ApplicationSet structure with sync wave ordering:

| Wave | Layer        | Apps                                    |
|------|--------------|-----------------------------------------|
| 0    | infra        | sealed-secrets, cert-manager, longhorn  |
| 1    | platform     | traefik, cloudflare-tunnel              |
| 2    | applications | (future workloads)                      |

Each app is a thin Helm wrapper: `Chart.yaml` (upstream dependency) + `values.yaml` (overrides).
ApplicationSets auto-discover app directories — adding an app is just creating a directory.

## Prerequisites

- Kubernetes cluster running with `kubectl` configured
- Helm 3 installed locally
- Git remote accessible from the cluster
- `kubeseal` CLI installed (for sealing secrets)
- Cloudflare account with a registered domain

## Bootstrap

### 1. Update repo URL

Replace all occurrences of `https://github.com/Rajagopal2000/homelab-gitops` with your actual repo URL in:
- `bootstrap/root.yaml`
- `appsets/infra.yaml`
- `appsets/platform.yaml`
- `appsets/applications.yaml`

### 2. Update cert-manager email

Replace `REPLACE_WITH_YOUR_EMAIL` in `infra/cert-manager/templates/clusterissuer.yaml` with your email address.

### 3. Install ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f bootstrap/argocd/values.yaml
```

### 4. Access ArgoCD UI

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 and login with username `admin` and the password from above.

### 5. Apply root Application

```bash
kubectl apply -f bootstrap/root.yaml
```

ArgoCD will now discover and deploy all layers automatically.

### 6. Seal and commit secrets

After sealed-secrets controller is running, create the required SealedSecrets:

**Cloudflare API Token (for cert-manager DNS-01):**

```bash
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=infra-sealed-secrets --controller-namespace=sealed-secrets -o yaml \
  > infra/cert-manager/templates/cloudflare-api-token-sealed.yaml
```

**Cloudflare Tunnel Token:**

```bash
kubectl create secret generic cloudflare-tunnel-credentials \
  --namespace cloudflare-tunnel \
  --from-literal=tunnelToken=YOUR_TUNNEL_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=infra-sealed-secrets --controller-namespace=sealed-secrets -o yaml \
  > platform/cloudflare-tunnel/templates/tunnel-credentials.yaml
```

Commit and push the sealed secrets:

```bash
git add infra/cert-manager/templates/ platform/cloudflare-tunnel/templates/
git commit -m "feat: add sealed secrets for cloudflare"
git push
```

## Adding a New App

1. Create a directory under the correct layer (`infra/`, `platform/`, or `applications/`)
2. Add `Chart.yaml` with the upstream chart as a dependency
3. Add `values.yaml` with your overrides
4. Commit and push — the ApplicationSet auto-discovers it

Example `Chart.yaml`:

```yaml
apiVersion: v2
name: my-app
version: 0.1.0
dependencies:
  - name: upstream-chart-name
    version: "1.0.0"
    repository: "https://example.com/helm-repo"
```

## Verify Deployment

```bash
# Check all ArgoCD applications
kubectl get applications -n argocd

# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check specific app sync status
kubectl get application <app-name> -n argocd -o jsonpath='{.status.sync.status}'
```

## Repository Structure

```
homelab-gitops/
├── bootstrap/          # One-time manual apply
│   ├── root.yaml       # Root Application → manages appsets/
│   └── argocd/         # ArgoCD self-managed Helm wrapper
├── appsets/            # ApplicationSet per layer
│   ├── infra.yaml      # Wave 0
│   ├── platform.yaml   # Wave 1
│   └── applications.yaml # Wave 2
├── infra/              # Infrastructure apps
│   ├── sealed-secrets/
│   ├── cert-manager/
│   └── longhorn/
├── platform/           # Platform apps
│   ├── traefik/
│   └── cloudflare-tunnel/
└── applications/       # Workload apps (future)
```
