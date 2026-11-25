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
  if existing=$(skopeo inspect --format '{{.Digest}}' "docker://$repository:$version" 2>"$work/inspect-error"); then
    [[ "$existing" == "$digest" ]] || { echo "Refusing to replace $repository:$version at $existing" >&2; exit 1; }
  elif ! grep -Eqi 'manifest unknown|name unknown' "$work/inspect-error"; then
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
  skopeo copy --all --preserve-digests "oci:$work/$variant:qualified" "docker://$repository:$candidate"
  (cd "$signed" && oras attach --artifact-type application/vnd.dev.sigstore.bundle.v0.3+json \
    "$repository@$digest" "$variant.sigstore.json:application/vnd.dev.sigstore.bundle.v0.3+json")
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    cosign sign --yes "$repository@$digest"
    cosign verify --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$repository@$digest" >/dev/null
  fi
  skopeo copy --all --preserve-digests "docker://$repository@$digest" "docker://$repository:$version"
  [[ $(skopeo inspect --format '{{.Digest}}' "docker://$repository:$version") == "$digest" ]]
  printf '%s\n' "$repository:$version@$digest"
done
