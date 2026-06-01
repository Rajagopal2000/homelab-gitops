# Elasticsearch + Kibana via ECK — Design

**Date:** 2026-06-01
**Status:** Approved design, pending implementation plan
**Author:** Rajagopal (with Claude)

## Goal

Add a small, highly-available Elasticsearch cluster with Kibana to the homelab
GitOps repo, deployed through ArgoCD using the same conventions as existing apps.

## Environment constraints (why the design looks the way it does)

- **Talos OS** worker nodes — locked down; privileged containers and node-level
  `sysctl` changes are restricted/manual. Talos config lives outside this repo
  (`/home/user/Project/_out`).
- **Longhorn** storage — RWX is broken on Talos, so **RWO only**; ~350Gi usable
  per node after the 30% reservation. Cluster recently recovered from a disk
  crisis, so we avoid anything that touches node/storage internals.
- **Traefik** exposes internal services on the **`web` entrypoint (HTTP, port 80)**.
  Browser-facing TLS terminates at the Cloudflare edge, not at internal routes.
  cert-manager/Let's Encrypt exists but is not wired into internal IngressRoutes.

## Decisions (from brainstorming)

| Decision | Choice |
|---|---|
| Deploy method | **ECK operator** (Elastic Cloud on Kubernetes) |
| Topology | **3-node** Elasticsearch cluster (HA quorum) |
| Storage per node | **50Gi** RWO Longhorn (150Gi total) |
| Kibana access | **Traefik internal IngressRoute** (`kibana.rajagopaliyer.com`, `web` entrypoint) |
| Security | **ES security ON**; **Kibana public-facing self-signed cert disabled** (HTTP at edge) |
| Version line | **Elasticsearch / Kibana 9.x** |

## Architecture

Two pieces, placed to respect ArgoCD sync-waves (`infra=0 → platform=1 → applications=2`)
so the CRDs exist before the CRs that consume them.

| Piece | Location | Sync-wave | Contents |
|---|---|---|---|
| ECK operator | `platform/eck-operator/` | 1 | `Chart.yaml` with `dependencies:` → `eck-operator` chart from `https://helm.elastic.co`; installs CRDs + operator into `elastic-system`. `values.yaml` for operator resources. |
| ES + Kibana instances | `applications/elasticsearch/` | 2 | Hand-rolled `templates/`: `Elasticsearch` CR, `Kibana` CR, Traefik `IngressRoute`. Namespace `elasticsearch` (auto-created by the ApplicationSet). |

The operator piece mirrors `infra/longhorn` / `infra/cert-manager` / `platform/traefik`
(upstream chart as a dependency). The instances piece mirrors `applications/minio`
(bare `Chart.yaml` + local templates).

### Components

- **Elasticsearch CR** (`elasticsearch.k8s.elastic.co/v1`)
  - One `nodeSet` with `count: 3` (HA quorum; survives one node restart without
    going read-only).
  - `volumeClaimTemplates`: `storage: 50Gi`, `storageClassName: longhorn`,
    `accessModes: [ReadWriteOnce]`.
  - Resources: memory limit `2Gi`/node → ECK auto-sizes JVM heap to ~1Gi
    (heap defaults to 50% of the memory limit). CPU request `500m`.
  - `config.node.store.allow_mmap: false` — see "Talos gotcha" below.
- **Kibana CR** (`kibana.k8s.elastic.co/v1`)
  - `count: 1`, `elasticsearchRef` pointing at the ES cluster (ECK auto-wires
    the TLS CA + a service account — no manual credentials).
  - `~1Gi` memory.
  - `spec.http.tls.selfSignedCertificate.disabled: true` → Kibana serves HTTP.
- **IngressRoute** (Traefik, `web` entrypoint)
  - `Host(\`kibana.rajagopaliyer.com\`)` → Kibana service, port 5601.

## Security model

- ES security is **ON**: ECK generates its own self-signed CA and encrypts
  transport (ES↔ES), the ES HTTP API, and Kibana→ES traffic. This is fully
  self-contained and **does not interact with cert-manager / Let's Encrypt**.
- The `elastic` superuser password is auto-generated into Secret
  `elasticsearch-es-elastic-user`. **No SealedSecret needed** — the operator
  owns this credential. Retrieve with:
  `kubectl get secret elasticsearch-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d`
- Only Kibana's **public-facing** self-signed cert is disabled, so it sits behind
  Traefik as plain HTTP exactly like MinIO/Longhorn. Login is still enforced.

## The Talos `vm.max_map_count` gotcha

Elasticsearch normally needs `vm.max_map_count=262144`, satisfied either by a
**privileged initContainer** (blocked by Talos pod-security by default) or by a
**Talos machine-config sysctl** (manual, outside this repo). To keep the whole
deployment declarative with **zero node changes**, we set
`node.store.allow_mmap: false` in the ES config. For a small homelab cluster the
performance cost is negligible.

**Alternative (optional, better performance):** add
`machine.sysctls: { vm.max_map_count: "262144" }` to the Talos worker machine
config and remove the `allow_mmap: false` line. Out of scope for this change.

## Versions

- **Elasticsearch / Kibana: 9.x** (latest stable 9 line).
- **ECK operator** must be a release that supports the 9.x stack — confirm the
  exact chart version against `https://helm.elastic.co/index.yaml` at
  implementation time and pin it in `Chart.yaml` (same as longhorn/traefik pin
  upstream versions).

## Storage footprint

3 × 50Gi = **150Gi** provisioned, alongside MinIO's 100Gi. Each ES pod gets its
own RWO PVC on a separate node, well within the ~350Gi/node Longhorn budget.

## Out of scope / explicitly NOT doing

- No SealedSecret (ECK manages the credential).
- No Talos machine-config edits.
- No changes to existing applications.
- No public Cloudflare exposure (LAN-only via Traefik).
- No custom Kibana browser TLS cert (edge TLS handled by Traefik/Cloudflare as
  with every other service).

## Post-deploy manual step

- Add a DNS record for `kibana.rajagopaliyer.com → 192.168.4.200` (local DNS or
  Cloudflare), matching the existing pattern for MinIO/Longhorn IngressRoutes.

## Verification

- ArgoCD shows `platform-eck-operator` (wave 1) and `app-elasticsearch` (wave 2)
  Healthy/Synced.
- `kubectl get elasticsearch,kibana -n elasticsearch` → `health: green`,
  `phase: Ready`.
- 3 ES pods Running, 3 bound 50Gi Longhorn PVCs.
- `kibana.rajagopaliyer.com` loads the login page; `elastic` + retrieved password
  logs in.
