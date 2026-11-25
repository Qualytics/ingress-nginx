#!/usr/bin/env bash
# Usage: chart-smoke.sh <local-controller:tag | registry/controller@sha256:digest> <self-hosted-checkout> [--chroot]
set -Eeuo pipefail
trap 'echo "Smoke test failed on line $LINENO: $BASH_COMMAND" >&2' ERR

candidate=${1:?pass a controller image}
source_chart=${2:?pass a Qualytics self-hosted chart checkout}/charts/qualytics
case "${3:-}" in
  "") chroot=false; digest_key=digest; upstream=controller ;;
  --chroot) chroot=true; digest_key=digestChroot; upstream=controller-chroot ;;
  *) echo "Expected --chroot or no third argument." >&2; exit 2 ;;
esac
[[ -f "$source_chart/templates/ingress.yaml" ]]
node_image=kindest/node:v1.35.5@sha256:ce977ae6d65918d0b58a5f8b5e940429c2ce42fa3a5619ec2bbc60b949c0ac95
host=ingress-smoke.test
cluster="qig-$(uuidgen | tr '[:upper:]' '[:lower:]')"
work=$(mktemp -d)
work=$(cd "$work" && pwd -P)
export KUBECONFIG="$work/kubeconfig"
context="kind-$cluster"
port_forward_pid=

k() { kubectl --kubeconfig "$KUBECONFIG" --context "$context" "$@"; }
h() { helm --kubeconfig "$KUBECONFIG" --kube-context "$context" "$@"; }
stop_forward() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" 2>/dev/null || true
    wait "$port_forward_pid" 2>/dev/null || true
    port_forward_pid=
  fi
}
cleanup() {
  local status=$?
  stop_forward
  if [[ "$status" != 0 && -s "$KUBECONFIG" ]]; then
    k get events --sort-by=.metadata.creationTimestamp | tail -25 || true
    k logs deployment/smoke-nginx-controller --tail=30 || true
  fi
  kind delete cluster --name "$cluster" --kubeconfig "$KUBECONFIG"
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Exercise the released ingress templates and exact vendored dependency without Qualytics application images.
chart="$work/qualytics"
mkdir -p "$chart/templates"
cp "$source_chart"/{Chart.yaml,Chart.lock,values.yaml} "$chart/"
cp -R "$source_chart/charts" "$chart/"
cp "$source_chart"/templates/{_helpers.tpl,ingress.yaml} "$chart/templates/"

kind create cluster --name "$cluster" --kubeconfig "$KUBECONFIG" --image "$node_image" --wait 3m
ref=${candidate%@*}
repository=$ref
tag=latest
if [[ "${ref##*/}" == *:* ]]; then
  repository=${ref%:*}
  tag=${ref##*:}
fi
digest=
if [[ "$candidate" == *@sha256:* ]]; then
  digest=${candidate##*@}
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]
elif [[ "${ref##*/}" == *:* ]] && docker image inspect "$candidate" >/dev/null; then
  kind load docker-image "$candidate" --name "$cluster"
else
  echo "Pass a published digest or a tagged image in the local Docker daemon." >&2
  exit 2
fi

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$host" \
  -addext "subjectAltName=DNS:$host" -keyout "$work/tls.key" -out "$work/tls.crt" 2>/dev/null
k create secret tls smoke-tls --cert="$work/tls.crt" --key="$work/tls.key"

for app in api frontend; do
  # Distinct files expose route or rewrite mistakes as a 404 or the wrong response.
  k create deployment "$app" --image=busybox:1.37.0 -- sh -ec '
    mkdir -p /www/api/anomalies/7/source-record /www/.well-known
    if [ "$1" = api ]; then
      echo api > /www/api/health
      echo stream > /www/api/anomalies/7/source-record/download
      echo metadata > /www/.well-known/metadata
    else
      echo frontend > /www/index.html
    fi
    exec httpd -f -p 8080 -h /www
  ' sh "$app"
  service_port=$(yq ".${app/api/controlplane}.ingress.servicePort" "$source_chart/values.yaml")
  k expose deployment "$app" --name="smoke-$app-service" --port="$service_port" --target-port=8080
  k rollout status deployment/"$app" --timeout=2m
done

check_release() {
  local expected=$1 port= route body actual pod admitted=false
  k rollout status deployment/smoke-nginx-controller --timeout=3m
  actual=$(k get deployment smoke-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].image}')
  [[ "$actual" == "$expected" ]] || { echo "Expected controller $expected, got $actual" >&2; return 1; }
  pod=$(k get pods -l app.kubernetes.io/component=controller,app.kubernetes.io/instance=smoke -o yaml |
    IMAGE="$expected" yq -r '.items[] | select(.metadata.deletionTimestamp == null and
      .spec.containers[0].image == strenv(IMAGE) and .status.containerStatuses[0].ready == true) | .metadata.name')
  [[ -n "$pod" ]]
  k get validatingwebhookconfiguration smoke-nginx-admission -o yaml |
    yq -e '.webhooks[0].failurePolicy == "Fail" and (.webhooks[0].clientConfig.caBundle | length > 0)' >/dev/null
  # During a rolling update the webhook Service can still route to a terminating pod.
  for _ in $(seq 1 20); do
    if k annotate ingress smoke-api-ingress smoke-check=ready --overwrite --dry-run=server >/dev/null 2>"$work/admission-error"; then
      admitted=true
      break
    fi
    sleep 1
  done
  [[ "$admitted" == true ]] || { cat "$work/admission-error" >&2; return 1; }
  # Route admission can finish before the controller has reloaded its live config.
  for _ in $(seq 1 30); do
    k exec "$pod" -- cat /etc/nginx/nginx.conf > "$work/nginx.conf"
    if grep -Fq 'source-record/download' "$work/nginx.conf" && grep -Fq 'owasp-modsecurity-crs/nginx-modsecurity.conf' "$work/nginx.conf"; then
      break
    fi
    sleep 1
  done
  grep -Fq 'SecRuleEngine On' "$work/nginx.conf"
  grep -Fq 'modsecurity_rules_file /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf;' "$work/nginx.conf"
  awk '/^[[:space:]]*location[[:space:]]/ {stream = /source-record\/download/}
       stream && /proxy_buffering[[:space:]]+off;/ {unbuffered = 1}
       stream && /proxy_read_timeout[[:space:]]+3600s;/ {long_read = 1}
       END {exit !(unbuffered && long_read)}' "$work/nginx.conf"

  k port-forward --address 127.0.0.1 "pod/$pod" :443 > "$work/forward.log" 2>&1 &
  port_forward_pid=$!
  for _ in $(seq 1 50); do
    port=$(sed -nE 's/^Forwarding from 127\.0\.0\.1:([0-9]+) .*/\1/p' "$work/forward.log")
    [[ -n "$port" ]] && break
    sleep 0.2
  done
  [[ -n "$port" ]] || { cat "$work/forward.log" >&2; return 1; }
  while read -r route body; do
    actual=$(curl -fsS --retry 8 --retry-all-errors --retry-delay 1 --max-time 5 \
      --noproxy '*' --cacert "$work/tls.crt" --resolve "$host:$port:127.0.0.1" \
      -D "$work/headers" "https://$host:$port$route")
    [[ "$actual" == "$body" ]] || { echo "$route returned '$actual'" >&2; return 1; }
    grep -Eiq '^x-frame-options:[[:space:]]*SAMEORIGIN[[:space:]]*$' "$work/headers"
  done <<'ROUTES'
/ frontend
/api/health api
/.well-known/metadata metadata
/api/anomalies/7/source-record/download stream
ROUTES
  stop_forward
  echo "Verified $expected"
}

values=(--set nginx.enabled=true --set ingress.enabled=true --set "global.dnsRecord=$host"
        --set ingress.tls.secretName=smoke-tls --set nginx.controller.service.type=NodePort
        --set "nginx.controller.image.chroot=$chroot")
h install smoke "$chart" "${values[@]}" --wait --timeout 4m
baseline=$(k get deploy smoke-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$baseline" == registry.k8s.io/ingress-nginx/"$upstream":*@sha256:* ]]
check_release "$baseline"

h upgrade smoke "$chart" --reuse-values --set-string "nginx.controller.image.repository=$repository" \
  --set-string "nginx.controller.image.tag=$tag" --set-string "nginx.controller.image.$digest_key=$digest" --wait --timeout 4m
check_release "$repository:$tag${digest:+@$digest}"

h rollback smoke 1 --wait --timeout 4m
check_release "$baseline"
