# BNK training lab on k3d (Terraform)

A local lab for F5 BIG-IP Next for Kubernetes (BNK) training, built with Terraform on a k3d cluster. The BNK parts stay off (`enable_bnk = false`) until you have F5 entitlement files (see `secrets/README.md`).

```
make up        # cluster + platform
make outputs   # URLs and passwords
make verify    # lab checks
make down      # tear it all down
```

## What gets built

| Stack | Contents |
|-------|----------|
| `00-cluster` | k3d cluster `bnk-lab`: 1 server, 2 agents, k3s v1.34, Traefik disabled. Writes `./kubeconfig` (for the host) and `./kubeconfig-forge` (for containers, using the host IP). |
| `10-platform` | cert-manager, Gateway API CRDs, kube-prometheus-stack, a `demo/demo-web` nginx backend, and bnk-forge (cloned to `./bnk-forge` and run with Docker Compose). With `enable_bnk = true` it also deploys FAR pull secrets, a CA ClusterIssuer, FLO, the CNEInstance, and the GatewayClass, Gateway and HTTPRoute. |

There are two stacks so the Kubernetes and Helm providers never plan against a cluster that doesn't exist yet.

### Ports on the host

| Port | What |
|------|------|
| 6550 | Kubernetes API |
| 9080 / 9443 | Cluster LoadBalancer :80 / :443 (Gateway traffic) |
| 3300 | Grafana (user `admin`, password from `make outputs`) |
| 443 / 80 | bnk-forge UI (user `admin`, password from `make outputs`) |
| 18000 / 18080 / 18081 | bnk-forge backend, frontend, MCP (debug only) |

bnk-forge runs in bridge mode (`docker-compose.local.yml` plus the generated `docker-compose.lab.yml`), not its default Linux host mode, because ports 8000 and 8080 are already taken on this machine.

## Lab steps

1. **Cluster:** `make cluster`, then `kubectl get nodes` (with `export KUBECONFIG=$PWD/kubeconfig`).
2. **CloudDocs:** work through <https://clouddocs.f5.com/training/community/Next/html/>.
3. **bnk-forge:** open https://localhost and log in as `admin`.
   - Kubernetes > Clusters > Add Cluster: paste `kubeconfig-forge`.
   - Settings: set the Module Library Git URL to `https://github.com/JLCode-tech/bnk-forge-modules.git` and the ref to `release/2.2`, then sync.
   - You can deploy BNK either through bnk-forge's wizard or with Terraform (`enable_bnk`). Pick one, not both.
4. **Gateway API:** `kubectl get gateway -A` should show `demo/demo-gateway` as Programmed (BNK only).
5. **Traffic and telemetry:** `curl -I http://localhost:9080` should return 200. Grafana is at http://localhost:3300.

## Enabling BNK

1. Put `far-credentials.json` and `bnk-license.jwt` in `secrets/`.
2. In `10-platform/terraform.tfvars`, set `enable_bnk = true`. Set `bnk_manifest_version` too if you're entitled to a version other than `2.2.1-3.2226.0-0.0.511`.
3. Run `make platform`, then `make verify`.

Known open item: TMM's data plane. The CNEInstance references two Multus NetworkAttachmentDefinitions (`network_attachments`, default `external-netdevice` and `internal-netdevice`). BNK expects SR-IOV, a DPU, or kernel-mode host-device interfaces, and none of these exist in k3d nodes, which are Docker containers. FLO and the control plane should come up. TMM will most likely need Multus plus NADs backed by extra Docker networks attached to the k3d node containers. That part has to be worked out and tested once credentials exist. `tmm_extra_env` is there for tuning.

When BNK is enabled, Terraform stops managing the upstream Gateway API CRDs. They stay installed, and FLO installs and adopts its own.
