#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/controller-images.sh"

chart=charts/ingress-nginx
version=$(yq -r '.controller.image.tag' "$chart/values.yaml")
tag="controller-$version"
repository=Qualytics/ingress-nginx
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

release_state() {
  gh release view "$tag" --repo "$repository" --json id,isDraft,targetCommitish,assets \
    --jq '{id,isDraft,targetCommitish,assets:([.assets[] | {id,name,digest}] | sort_by(.name))}'
}

if ! draft=$(release_state); then
  echo "Controller release $tag must be staged before the chart can be published." >&2
  exit 1
fi
if [[ $(jq -r '.isDraft' <<< "$draft") == false ]]; then
  exit 0
fi

expected=()
for variant in "${controller_images[@]}"; do
  expected+=("$variant.index.json" "$variant.sigstore.json")
  for arch in amd64 arm64; do
    expected+=("$variant-$arch.attestation.json" "$variant-$arch.spdx.intoto.json")
  done
done
diff -u <(printf '%s\n' "${expected[@]}" | sort) <(jq -r '.assets[].name' <<< "$draft" | sort) >&2

gh release download "$tag" --repo "$repository" --dir "$work" --pattern '*.json'
for variant in "${controller_images[@]}"; do
  index="$variant.index.json"
  cmp "$chart/provenance/$version/$index" "$work/$index" >&2
  case "$variant" in
    controller) field=.controller.image.digest ;;
    controller-chroot) field=.controller.image.digestChroot ;;
    controller-webhook-certgen) field=.controller.admissionWebhooks.patch.image.digest ;;
  esac
  pin=$(yq -r "$field" "$chart/values.yaml")
  [[ "sha256:$(sha256sum "$work/$index" | cut -d ' ' -f 1)" == "$pin" ]] || {
    echo "$index differs from the chart's $field pin." >&2
    exit 1
  }
  revision=$(jq -er '.annotations["org.opencontainers.image.revision"]' "$work/$index")
  [[ "$revision" =~ ^[0-9a-f]{40}$ && "$revision" == "$(jq -r '.targetCommitish' <<< "$draft")" ]] || {
    echo "Release $tag must target the signed controller commit $revision." >&2
    exit 1
  }
  for arch in amd64 arm64; do
    bash build/verify-controller-sbom.sh "$work" "$variant" "$arch" "$version" >/dev/null
  done
done
[[ "$(release_state)" == "$draft" ]] || { echo "Release $tag changed during verification." >&2; exit 1; }
printf '%s\n' "$tag"
