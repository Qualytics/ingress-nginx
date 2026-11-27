#!/usr/bin/env bash
set -euo pipefail

image=${1:?pass the local webhook image with an explicit tag}
node=${2:?pass a pinned kind Kubernetes version and digest}
work=$(mktemp -d)
export KUBECONFIG="$work/kubeconfig"
cluster="qwh-$(uuidgen | tr '[:upper:]' '[:lower:]')"
cleanup() {
  local status=$?
  if [[ $status -ne 0 && -s "$KUBECONFIG" ]]; then
    kubectl get jobs,pods -l app.kubernetes.io/component=admission-webhook || true
    kubectl logs -l app.kubernetes.io/component=admission-webhook --tail=25 || true
  fi
  kind delete cluster --name "$cluster" --kubeconfig "$KUBECONFIG"
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

kind create cluster --name "$cluster" --kubeconfig "$KUBECONFIG" --image "kindest/node:$node" --wait 3m
kind load docker-image "$image" --name "$cluster"

release=hook
admission="$release-ingress-nginx-admission"
values=(
  --set controller.replicaCount=0
  --set controller.service.type=ClusterIP
  --set-string "controller.admissionWebhooks.patch.image.repository=${image%:*}"
  --set-string "controller.admissionWebhooks.patch.image.tag=${image##*:}"
  --set-string controller.admissionWebhooks.patch.image.digest=
  --set-string controller.admissionWebhooks.patch.image.pullPolicy=Never
  --wait --timeout 3m --hide-notes
)
helm install "$release" charts/ingress-nginx "${values[@]}"
ca=$(kubectl get secret "$admission" -o jsonpath='{.data.ca}')
[[ -n "$ca" && "$ca" == "$(kubectl get validatingwebhookconfiguration "$admission" -o jsonpath='{.webhooks[0].clientConfig.caBundle}')" ]]
printf '%s' "$ca" | openssl base64 -d -A > "$work/ca.pem"
kubectl get secret "$admission" -o jsonpath='{.data.cert}' | openssl base64 -d -A > "$work/server.pem"
openssl verify -CAfile "$work/ca.pem" -verify_hostname "$release-ingress-nginx-controller-admission.default.svc" "$work/server.pem"

# A successful upgrade reuses the Secret and restores the webhook's CA.
kubectl patch validatingwebhookconfiguration "$admission" --type=json \
  -p '[{"op":"remove","path":"/webhooks/0/clientConfig/caBundle"}]'
helm upgrade "$release" charts/ingress-nginx "${values[@]}"
[[ "$ca" == "$(kubectl get secret "$admission" -o jsonpath='{.data.ca}')" ]]
[[ "$ca" == "$(kubectl get validatingwebhookconfiguration "$admission" -o jsonpath='{.webhooks[0].clientConfig.caBundle}')" ]]
echo "Verified admission certificate creation, reuse and CA patching on Kubernetes ${node%@*}"
