# Homelab App-of-Apps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up an ArgoCD App-of-Apps GitOps repository with ApplicationSets for a single-node homelab Kubernetes cluster.

**Architecture:** Three-layer ApplicationSet structure (infra → platform → applications) with sync wave ordering. Each app is a thin Helm wrapper chart (Chart.yaml dependency + values.yaml overrides). ArgoCD bootstraps manually then self-manages via GitOps.

**Tech Stack:** Kubernetes, ArgoCD, Helm, sealed-secrets, cert-manager, Longhorn, Traefik, Cloudflare Tunnel

**Spec:** `docs/superpowers/specs/2026-03-29-homelab-app-of-apps-design.md`

---

## File Structure

```
homelab-setup/
├── bootstrap/
│   ├── root.yaml
│   └── argocd/
│       ├── Chart.yaml
│       └── values.yaml
├── appsets/
│   ├── infra.yaml
│   ├── platform.yaml
│   └── applications.yaml
├── infra/
│   ├── sealed-secrets/
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── cert-manager/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── clusterissuer.yaml
│   └── longhorn/
│       ├── Chart.yaml
│       └── values.yaml
├── platform/
│   ├── traefik/
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   └── cloudflare-tunnel/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           └── tunnel-credentials.yaml
├── applications/
│   └── .gitkeep
├── .gitignore
└── README.md
```

**Note on SealedSecrets:** The spec calls for SealedSecret manifests in `templates/` for cert-manager and cloudflare-tunnel. These require a running sealed-secrets controller and the `kubeseal` CLI to generate. The plan creates placeholder Secret templates with clear instructions — the user must seal them against their cluster after sealed-secrets is deployed. The cert-manager directory also includes a `ClusterIssuer` resource for Let's Encrypt DNS-01 via Cloudflare.

---

### Task 1: Initialize Git Repository and .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Initialize git repo**

Run: `git init`
Expected: `Initialized empty Git repository`

- [ ] **Step 2: Create .gitignore**

Create `.gitignore`:

```gitignore
# Helm
charts/
*.tgz
Chart.lock

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Secrets - never commit unsealed secrets
**/secrets/
*.key
*.pem
```

- [ ] **Step 3: Create applications/.gitkeep**

Create `applications/.gitkeep` (empty file) so the empty directory is tracked by git.

- [ ] **Step 4: Commit**

```bash
git add .gitignore applications/.gitkeep
git commit -m "chore: initialize repo with gitignore"
```

---

### Task 2: ArgoCD Bootstrap — Chart.yaml and values.yaml

**Files:**
- Create: `bootstrap/argocd/Chart.yaml`
- Create: `bootstrap/argocd/values.yaml`

- [ ] **Step 1: Create bootstrap/argocd/Chart.yaml**

```yaml
apiVersion: v2
name: argocd
description: ArgoCD self-managed Helm wrapper
version: 0.1.0
dependencies:
  - name: argo-cd
    version: "9.4.17"
    repository: "https://argoproj.github.io/argo-helm"
```

- [ ] **Step 2: Create bootstrap/argocd/values.yaml**

This configures ArgoCD for a single-node homelab. Key settings: disable HA (single node), enable ApplicationSet controller, set the repo URL.

```yaml
argo-cd:
  global:
    domain: argocd.localhost

  configs:
    params:
      # Single node — no HA needed
      server.insecure: true

  # Controller
  controller:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        memory: 512Mi

  # Server
  server:
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        memory: 256Mi

  # Repo server
  repoServer:
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        memory: 256Mi

  # ApplicationSet controller
  applicationSet:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi

  # Redis
  redis:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi

  # Disable components not needed for single-node homelab
  dex:
    enabled: false
  notifications:
    enabled: false
```

- [ ] **Step 3: Commit**

```bash
git add bootstrap/argocd/
git commit -m "feat: add ArgoCD bootstrap Helm wrapper"
```

---

### Task 3: Root Application

**Files:**
- Create: `bootstrap/root.yaml`

- [ ] **Step 1: Create bootstrap/root.yaml**

This is the root Application that manages the `appsets/` directory. It is the single entry point — after applying this, ArgoCD discovers and manages everything else.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Rajagopal2000/homelab-gitops
    targetRevision: HEAD
    path: appsets
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Note:** Replace `https://github.com/Rajagopal2000/homelab-gitops` with your actual repo URL before bootstrap. This placeholder appears in this file and all ApplicationSet files.

- [ ] **Step 2: Commit**

```bash
git add bootstrap/root.yaml
git commit -m "feat: add root Application for app-of-apps"
```

---

### Task 4: ApplicationSets — infra, platform, applications

**Files:**
- Create: `appsets/infra.yaml`
- Create: `appsets/platform.yaml`
- Create: `appsets/applications.yaml`

- [ ] **Step 1: Create appsets/infra.yaml**

Sync wave `0` — deploys first. Discovers all directories under `infra/`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infra
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        revision: HEAD
        directories:
          - path: infra/*
  template:
    metadata:
      name: "infra-{{.path.basename}}"
      namespace: argocd
      labels:
        app.kubernetes.io/part-of: homelab
        app.kubernetes.io/component: infra
    spec:
      project: default
      source:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        targetRevision: HEAD
        path: "{{.path.path}}"
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

- [ ] **Step 2: Create appsets/platform.yaml**

Sync wave `1` — deploys after infra.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        revision: HEAD
        directories:
          - path: platform/*
  template:
    metadata:
      name: "platform-{{.path.basename}}"
      namespace: argocd
      labels:
        app.kubernetes.io/part-of: homelab
        app.kubernetes.io/component: platform
    spec:
      project: default
      source:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        targetRevision: HEAD
        path: "{{.path.path}}"
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

- [ ] **Step 3: Create appsets/applications.yaml**

Sync wave `2` — deploys last.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: applications
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        revision: HEAD
        directories:
          - path: applications/*
  template:
    metadata:
      name: "app-{{.path.basename}}"
      namespace: argocd
      labels:
        app.kubernetes.io/part-of: homelab
        app.kubernetes.io/component: application
    spec:
      project: default
      source:
        repoURL: https://github.com/Rajagopal2000/homelab-gitops
        targetRevision: HEAD
        path: "{{.path.path}}"
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

- [ ] **Step 4: Commit**

```bash
git add appsets/
git commit -m "feat: add ApplicationSets for infra, platform, and applications layers"
```

---

### Task 5: Infra — sealed-secrets

**Files:**
- Create: `infra/sealed-secrets/Chart.yaml`
- Create: `infra/sealed-secrets/values.yaml`

- [ ] **Step 1: Create infra/sealed-secrets/Chart.yaml**

```yaml
apiVersion: v2
name: sealed-secrets
description: Bitnami Sealed Secrets controller
version: 0.1.0
dependencies:
  - name: sealed-secrets
    version: "2.18.4"
    repository: "https://bitnami-labs.github.io/sealed-secrets"
```

- [ ] **Step 2: Create infra/sealed-secrets/values.yaml**

```yaml
sealed-secrets:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 128Mi
```

- [ ] **Step 3: Commit**

```bash
git add infra/sealed-secrets/
git commit -m "feat: add sealed-secrets infra app"
```

---

### Task 6: Infra — cert-manager

**Files:**
- Create: `infra/cert-manager/Chart.yaml`
- Create: `infra/cert-manager/values.yaml`
- Create: `infra/cert-manager/templates/clusterissuer.yaml`

- [ ] **Step 1: Create infra/cert-manager/Chart.yaml**

```yaml
apiVersion: v2
name: cert-manager
description: cert-manager with Let's Encrypt DNS-01 via Cloudflare
version: 0.1.0
dependencies:
  - name: cert-manager
    version: "v1.20.1"
    repository: "https://charts.jetstack.io"
```

- [ ] **Step 2: Create infra/cert-manager/values.yaml**

```yaml
cert-manager:
  installCRDs: true
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 256Mi
```

- [ ] **Step 3: Create infra/cert-manager/templates/clusterissuer.yaml**

This creates a ClusterIssuer for Let's Encrypt using Cloudflare DNS-01 challenge. The Cloudflare API token must be provided as a Kubernetes Secret (or SealedSecret) named `cloudflare-api-token` in the `cert-manager` namespace with key `api-token`.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: REPLACE_WITH_YOUR_EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: REPLACE_WITH_YOUR_EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

**Note:** Replace `REPLACE_WITH_YOUR_EMAIL` with your email. The `cloudflare-api-token` Secret must be created manually and sealed with `kubeseal` after sealed-secrets is running. Example:

```bash
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml \
  > infra/cert-manager/templates/cloudflare-api-token-sealed.yaml
```

- [ ] **Step 4: Commit**

```bash
git add infra/cert-manager/
git commit -m "feat: add cert-manager infra app with ClusterIssuer"
```

---

### Task 7: Infra — Longhorn

**Files:**
- Create: `infra/longhorn/Chart.yaml`
- Create: `infra/longhorn/values.yaml`

- [ ] **Step 1: Create infra/longhorn/Chart.yaml**

```yaml
apiVersion: v2
name: longhorn
description: Longhorn distributed block storage
version: 0.1.0
dependencies:
  - name: longhorn
    version: "1.11.1"
    repository: "https://charts.longhorn.io"
```

- [ ] **Step 2: Create infra/longhorn/values.yaml**

Single-node config — default replica count of 1 since there's only one node.

```yaml
longhorn:
  defaultSettings:
    defaultReplicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 256Mi
```

- [ ] **Step 3: Commit**

```bash
git add infra/longhorn/
git commit -m "feat: add longhorn infra app"
```

---

### Task 8: Platform — Traefik

**Files:**
- Create: `platform/traefik/Chart.yaml`
- Create: `platform/traefik/values.yaml`

- [ ] **Step 1: Create platform/traefik/Chart.yaml**

```yaml
apiVersion: v2
name: traefik
description: Traefik ingress controller
version: 0.1.0
dependencies:
  - name: traefik
    version: "39.0.6"
    repository: "https://traefik.github.io/charts"
```

- [ ] **Step 2: Create platform/traefik/values.yaml**

Configured for LAN access on a single node. Uses NodePort as a simple option for homelab (no cloud LoadBalancer). Ports 80 and 443 exposed.

```yaml
traefik:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 256Mi

  ports:
    web:
      exposedPort: 80
    websecure:
      exposedPort: 443

  service:
    type: LoadBalancer

  ingressRoute:
    dashboard:
      enabled: false
```

- [ ] **Step 3: Commit**

```bash
git add platform/traefik/
git commit -m "feat: add traefik platform app"
```

---

### Task 9: Platform — Cloudflare Tunnel

**Files:**
- Create: `platform/cloudflare-tunnel/Chart.yaml`
- Create: `platform/cloudflare-tunnel/values.yaml`
- Create: `platform/cloudflare-tunnel/templates/tunnel-credentials.yaml`

- [ ] **Step 1: Create platform/cloudflare-tunnel/Chart.yaml**

```yaml
apiVersion: v2
name: cloudflare-tunnel
description: Cloudflare Tunnel for external access
version: 0.1.0
dependencies:
  - name: cloudflare-tunnel-remote
    version: "0.1.2"
    repository: "https://cloudflare.github.io/helm-charts"
```

- [ ] **Step 2: Create platform/cloudflare-tunnel/values.yaml**

The Cloudflare tunnel is configured remotely via the Cloudflare dashboard. The Helm chart just needs the tunnel token to connect.

```yaml
cloudflare-tunnel-remote:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 128Mi
```

- [ ] **Step 3: Create platform/cloudflare-tunnel/templates/tunnel-credentials.yaml**

Placeholder — must be sealed after sealed-secrets is running. The tunnel token is obtained from the Cloudflare Zero Trust dashboard when creating a tunnel.

```yaml
# This file should be replaced with a SealedSecret.
# To create:
# 1. Create a tunnel in Cloudflare Zero Trust dashboard
# 2. Copy the tunnel token
# 3. Run:
#    kubectl create secret generic tunnel-credentials \
#      --namespace cloudflare-tunnel \
#      --from-literal=TUNNEL_TOKEN=YOUR_TUNNEL_TOKEN \
#      --dry-run=client -o yaml | \
#      kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml \
#      > platform/cloudflare-tunnel/templates/tunnel-credentials.yaml
#
# Then commit the resulting SealedSecret.
```

- [ ] **Step 4: Commit**

```bash
git add platform/cloudflare-tunnel/
git commit -m "feat: add cloudflare-tunnel platform app"
```

---

### Task 10: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

```markdown
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
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml \
  > infra/cert-manager/templates/cloudflare-api-token-sealed.yaml
```

**Cloudflare Tunnel Token:**

```bash
kubectl create secret generic tunnel-credentials \
  --namespace cloudflare-tunnel \
  --from-literal=TUNNEL_TOKEN=YOUR_TUNNEL_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml \
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
homelab-setup/
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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with bootstrap instructions and repo overview"
```

---

### Task 11: Final Validation

- [ ] **Step 1: Verify all files exist**

Run:

```bash
find . -type f -not -path './.git/*' -not -path './.claude/*' | sort
```

Expected output should include all files from the file structure above.

- [ ] **Step 2: Validate YAML syntax**

Run:

```bash
for f in $(find . -name '*.yaml' -not -path './.git/*' -not -path './.claude/*'); do
  echo "Checking $f"
  python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>&1 || echo "FAIL: $f"
done
```

All files should pass. Files with multiple documents (`---` separator) or comment-only files will show warnings — that's fine.

- [ ] **Step 3: Verify no real secrets are committed**

Run:

```bash
grep -r "YOUR_" . --include='*.yaml' -not -path './.git/*'
```

Should only find placeholder strings like `YOUR_CLOUDFLARE_API_TOKEN` and `YOUR_TUNNEL_TOKEN` in template/instruction files — never actual credentials.

- [ ] **Step 4: Final commit (if any uncommitted changes)**

```bash
git status
```

If clean, this task is done. If there are uncommitted files, stage and commit them.
