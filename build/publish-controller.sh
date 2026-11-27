#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/controller-images.sh"

archives=${1:?pass the directory containing the qualified OCI archives}
signed=${2:?pass the directory containing the signed index JSON and Sigstore bundles}
signed=$(cd "$signed" && pwd)
version=$(cat TAG)
identity=https://github.com/Qualytics/ingress-nginx/.github/workflows/qualytics-controller.yml@refs/heads/main
issuer=https://token.actions.githubusercontent.com
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash build/package-controller.sh "$archives" "$work"
for variant in "${controller_images[@]}"; do
  ref=$(controller_image_ref "$variant" "$version")
  index="$work/$variant.index.json"
  cmp "$index" "$signed/$variant.index.json"
  cosign verify-blob --bundle "$signed/$variant.sigstore.json" \
    --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$index"
  digest="sha256:$(shasum -a 256 "$index" | cut -d ' ' -f 1)"
  if descriptor=$(oras manifest fetch --descriptor "$ref" 2>"$work/inspect-error"); then
    existing=$(jq -er '.digest' <<< "$descriptor")
    [[ "$existing" == "$digest" ]] || { echo "Refusing to replace $ref at $existing" >&2; exit 1; }
  elif ! grep -Eqi ': not found$|manifest unknown|name unknown' "$work/inspect-error"; then
    cat "$work/inspect-error" >&2
    exit 1
  fi
done

for variant in "${controller_images[@]}"; do
  ref=$(controller_image_ref "$variant" "$version")
  repository=${ref%:*}
  index="$work/$variant.index.json"
  digest="sha256:$(shasum -a 256 "$index" | cut -d ' ' -f 1)"
  # Scan the exact staged index on both platforms before publishing any release tag.
  candidate="candidate-${digest#sha256:}"
  oras cp --from-oci-layout "$work/$variant:qualified" "$repository:$candidate"
  for arch in amd64 arm64; do
    docker scout cves --platform "linux/$arch" --only-severity critical,high --exit-code "registry://$repository@$digest"
  done
done

for variant in "${controller_images[@]}"; do
  ref=$(controller_image_ref "$variant" "$version")
  repository=${ref%:*}
  digest="sha256:$(shasum -a 256 "$work/$variant.index.json" | cut -d ' ' -f 1)"
  (cd "$signed" && oras attach --artifact-type application/vnd.dev.sigstore.bundle.v0.3+json \
    "$repository@$digest" "$variant.sigstore.json:application/vnd.dev.sigstore.bundle.v0.3+json")
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    cosign sign --yes "$repository@$digest"
    cosign verify --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$repository@$digest" >/dev/null
  fi
  oras tag "$repository@$digest" "${ref##*:}"
  [[ $(oras manifest fetch --descriptor "$ref" | jq -er '.digest') == "$digest" ]]
  printf '%s\n' "$ref@$digest"
done

# Publish verification material and SBOMs without distributing the private image layers.
tag="controller-$version"
metadata=("$signed"/*.index.json "$signed"/*.sigstore.json "$work"/*.attestation.json "$work"/*.spdx.intoto.json)
if published=$(gh release view "$tag" --repo Qualytics/ingress-nginx --json assets --jq '.assets[].name'); then
  missing=()
  mkdir "$work/published"
  for file in "${metadata[@]}"; do
    name=$(basename "$file")
    if grep -Fxq -- "$name" <<< "$published"; then
      gh release download "$tag" --repo Qualytics/ingress-nginx --dir "$work/published" --pattern "$name"
      cmp "$file" "$work/published/$name"
    else
      missing+=("$file")
    fi
  done
  if (( ${#missing[@]} )); then
    gh release upload "$tag" --repo Qualytics/ingress-nginx "${missing[@]}"
  fi
else
  gh release create "$tag" "${metadata[@]}" --repo Qualytics/ingress-nginx --draft \
    --target "$(git rev-parse HEAD)" --latest=false --title "Qualytics ingress-nginx $version" \
    --notes "Signed multiarchitecture image indexes, Sigstore bundles and software bills of materials for the standard controller, chroot controller and admission webhook certificate helper. Images are available to authenticated Qualytics customers on Docker Hub."
fi
