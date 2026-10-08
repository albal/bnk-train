# secrets/

Put your F5 entitlement files here. Git ignores everything in this folder except this README.

| File | What it is | Where to get it |
|------|-----------|-----------------|
| `far-credentials.json` | F5 Artifact Registry (FAR) service-account key. It is already base64-encoded, so don't decode it. | MyF5 → Resources → Downloads → BIG-IP_Next → BIG-IP Next for Kubernetes → `f5-far-auth-key.tar`. Run `tar -xf f5-far-auth-key.tar` and rename `cne_pull_64.json` to `far-credentials.json`. |
| `bnk-license.jwt` | BNK license JWT, a single line of text | MyF5 account → your BNK subscription or eval entitlement |

Once both files are here, set `enable_bnk = true` in `10-platform/terraform.tfvars` and run `make up`.
