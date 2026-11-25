#!/usr/bin/env bash
set -euo pipefail

archives=${1:?pass the directory containing the four qualified OCI archives}
signed=${2:?pass the directory containing the signed index JSON and Sigstore bundles}
signed=$(cd "$signed" && pwd)
version=$(cat TAG)
identity=https://github.com/Qualytics/ingress-nginx/.github/workflows/qualytics-controller.yml@refs/heads/main
issuer=https://token.actions.githubusercontent.com
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash build/package-controller.sh "$archives" "$work"
for variant in controller controller-chroot; do
  repository="docker.io/qualyticsai/ingress-nginx-$variant"
  index="$work/$variant.index.json"
  cmp "$index" "$signed/$variant.index.json"
  cosign verify-blob --bundle "$signed/$variant.sigstore.json" \
    --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$index"
  digest="sha256:$(shasum -a 256 "$index" | cut -d ' ' -f 1)"
  if descriptor=$(oras manifest fetch --descriptor "$repository:$version" 2>"$work/inspect-error"); then
    existing=$(jq -er '.digest' <<< "$descriptor")
    [[ "$existing" == "$digest" ]] || { echo "Refusing to replace $repository:$version at $existing" >&2; exit 1; }
  elif ! grep -Eqi ': not found$|manifest unknown|name unknown' "$work/inspect-error"; then
    cat "$work/inspect-error" >&2
    exit 1
  fi
done

for variant in controller controller-chroot; do
  repository="docker.io/qualyticsai/ingress-nginx-$variant"
  index="$work/$variant.index.json"
  digest="sha256:$(shasum -a 256 "$index" | cut -d ' ' -f 1)"
  # Publish a staging reference before moving the immutable version tag.
  candidate="candidate-${digest#sha256:}"
  oras cp --from-oci-layout "$work/$variant:qualified" "$repository:$candidate"
  (cd "$signed" && oras attach --artifact-type application/vnd.dev.sigstore.bundle.v0.3+json \
    "$repository@$digest" "$variant.sigstore.json:application/vnd.dev.sigstore.bundle.v0.3+json")
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    cosign sign --yes "$repository@$digest"
    cosign verify --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$repository@$digest" >/dev/null
  fi
  oras tag "$repository@$digest" "$version"
  [[ $(oras manifest fetch --descriptor "$repository:$version" | jq -er '.digest') == "$digest" ]]
  printf '%s\n' "$repository:$version@$digest"
done
