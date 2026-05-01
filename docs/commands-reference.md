# Homelab Commands Reference

## ArgoCD

```bash
# List all ArgoCD applications
kubectl get applications -n argocd

# Check specific app status
kubectl get app <app-name> -n argocd

# Force sync an app to latest commit
kubectl patch app <app-name> -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Force sync with apply (for stuck resources)
kubectl patch app <app-name> -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","syncStrategy":{"apply":{"force":true}}}}}'

# Clear a stuck sync operation
kubectl patch app <app-name> -n argocd --type json \
  -p='[{"op":"remove","path":"/status/operationState"}]'

# Check which revision ArgoCD has synced
kubectl get app <app-name> -n argocd -o jsonpath='{.status.sync.revision}'

# Check sync error details
kubectl get app <app-name> -n argocd -o jsonpath='{.status.operationState.message}'
```

## Talos OS

```bash
# Check disks on a node
talosctl get disks -e <node-ip> -n <node-ip>

# Check services on a node
talosctl -e <node-ip> -n <node-ip> services

# View kernel logs
talosctl -e <node-ip> -n <node-ip> dmesg

# Apply machine config
talosctl apply-config -n <node-ip> -f worker.yaml

# Upgrade node with new image (e.g., with system extensions)
talosctl upgrade -n <node-ip> --image factory.talos.dev/installer/<schematic-id>:v1.12.5

# Check mounts
talosctl -e <node-ip> -n <node-ip> mounts
```

## Longhorn

```bash
# Check Longhorn node storage and disks
kubectl get nodes.longhorn.io -n longhorn -o custom-columns='NAME:.metadata.name,SCHEDULABLE:.spec.allowScheduling,DISKS:.spec.disks'

# Check volume status
kubectl get volumes.longhorn.io -n longhorn

# Check Longhorn settings
kubectl get settings.longhorn.io -n longhorn
```

## Kubernetes Secrets

```bash
# Read a secret value
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 -d

# Create and seal a secret (for git-safe storage)
kubectl create secret generic <name> \
  --namespace <namespace> \
  --from-literal=<key>=<value> \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=infra-sealed-secrets \
           --controller-namespace=sealed-secrets -o yaml
```

## Debugging Pods

```bash
# Check pod status in a namespace
kubectl get pods -n <namespace>

# Check pod logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name>

# Follow logs in real-time
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name> -f

# Check why a pod is failing
kubectl describe pod <pod-name> -n <namespace>

# Check events (sorted by time)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Force delete stuck pods
kubectl delete pods -n <namespace> --all --force --grace-period=0

# Restart a deployment
kubectl rollout restart deployment/<name> -n <namespace>
```

## PVC / Storage

```bash
# List PVCs
kubectl get pvc -n <namespace>

# Delete a stuck PVC (remove finalizers first)
kubectl patch pvc <name> -n <namespace> --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl delete pvc <name> -n <namespace>
```

## Namespace

```bash
# Force delete a stuck namespace
kubectl get ns <name> -o json | python3 -c "import sys,json; ns=json.load(sys.stdin); ns['spec']['finalizers']=[]; json.dump(ns, sys.stdout)" | kubectl replace --raw "/api/v1/namespaces/<name>/finalize" -f -
```

## Node Resources

```bash
# Check resource allocation across worker nodes
for node in talos-d3i-sbn talos-l14-w85 talos-mrx-uq1 talos-yo4-9ml; do
  echo "=== $node ==="; kubectl describe node $node | grep -A5 "Allocated resources"
done
```

## Headscale (if re-enabled)

```bash
# Create a user
kubectl exec -n headscale deploy/headscale -- headscale users create <username>

# Create a preauthkey
kubectl exec -n headscale deploy/headscale -- headscale preauthkeys create --user <username> --reusable --expiration 365d

# List nodes
kubectl exec -n headscale deploy/headscale -- headscale nodes list

# Create API key
kubectl exec -n headscale deploy/headscale -- headscale apikeys create --expiration 90d

# List and enable routes
kubectl exec -n headscale deploy/headscale -- headscale routes list
kubectl exec -n headscale deploy/headscale -- headscale routes enable -r <route-id>
```
