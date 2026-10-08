#!/usr/bin/env bash
# Lab checks for steps 1-5. Checks that need BNK are skipped while enable_bnk = false.
set -uo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/kubeconfig"

pass=0 fail=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; fail=$((fail+1)); }
skip() { echo "  SKIP  $*"; }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }

bnk=$(cd 10-platform && terraform output -raw bnk_enabled 2>/dev/null || echo false)

echo "Step 1: cluster"
check "all nodes Ready" bash -c '! kubectl get nodes --no-headers | grep -v " Ready "'

echo "Platform"
check "cert-manager Available" kubectl -n cert-manager wait --for=condition=Available deploy --all --timeout=10s
check "Gateway API CRDs installed" kubectl get crd gateways.gateway.networking.k8s.io
check "Prometheus/Grafana Available" kubectl -n monitoring wait --for=condition=Available deploy --all --timeout=10s
check "Grafana responds on :3300" curl -fsS http://localhost:3300/api/health
check "demo app Available" kubectl -n demo wait --for=condition=Available deploy/demo-web --timeout=10s

echo "Step 3: bnk-forge"
if [ -d bnk-forge ]; then
  check "bnk-forge UI responds on https://localhost" curl -fsSk -o /dev/null https://localhost/
  check "bnk-forge API health" curl -fsSk https://localhost/api/system/health
else
  skip "bnk-forge not deployed (enable_forge = false)"
fi

echo "Steps 3-5: BNK"
if [ "$bnk" = "true" ]; then
  check "F5 pods Running" bash -c 'kubectl get pods -A | grep -i f5 | grep -q Running && ! kubectl get pods -A | grep -i f5 | grep -vqE "Running|Completed"'
  check "Gateway Programmed" kubectl -n demo wait --for=condition=Programmed gateway/demo-gateway --timeout=10s
  check "curl http://localhost:9080 returns 200" bash -c 'curl -sI http://localhost:9080 | head -1 | grep -q " 200"'
else
  skip "enable_bnk = false (F5 pods, Gateway Programmed, curl 200)"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
