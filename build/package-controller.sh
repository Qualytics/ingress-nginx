#!/usr/bin/env bash
set -euo pipefail

archives=${1:?pass the directory containing the four qualified OCI archives}
output=${2:?pass an empty output directory}
version=$(cat TAG)
revision=$(git rev-parse HEAD)
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-qualytics\.[0-9]+$ ]] || { echo "Invalid Qualytics TAG: $version" >&2; exit 1; }
mkdir -p "$output"
for variant in controller controller-chroot; do
  layout="$output/$variant"
  mkdir "$layout"
  for arch in amd64 arm64; do
    skopeo copy --all --preserve-digests "oci-archive:$archives/$variant-$arch.tar" "oci:$layout:$arch"
    manifest="$layout/$arch.index"
    skopeo inspect --raw "oci:$layout:$arch" > "$manifest"
    runnable=$(jq -er --arg arch "$arch" \
      '[.manifests[] | select(.platform.os == "linux" and .platform.architecture == $arch)] | select(length == 1) | .[0].digest' "$manifest")
    attestation=$(jq -er --arg digest "$runnable" \
      '.manifests[] | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest" and .annotations["vnd.docker.reference.digest"] == $digest) | .digest' "$manifest")
    attest_manifest="$layout/blobs/sha256/${attestation#sha256:}"
    jq -e '
      [.layers[].annotations["in-toto.io/predicate-type"]] as $types |
      any($types[]; . == "https://spdx.dev/Document") and
      any($types[]; startswith("https://slsa.dev/provenance/"))
    ' "$attest_manifest" >/dev/null
    sbom=$(jq -er '.layers[] | select(.annotations["in-toto.io/predicate-type"] == "https://spdx.dev/Document") | .digest' "$attest_manifest")
    sbom_blob="$layout/blobs/sha256/${sbom#sha256:}"
    jq -e '[.predicate.packages[] | select(.name == "libxml2") | .versionInfo] | unique == ["2.13.9-r4"]' "$sbom_blob" >/dev/null
    cp "$attest_manifest" "$output/$variant-$arch.attestation.json"
    cp "$sbom_blob" "$output/$variant-$arch.spdx.intoto.json"
  done
  index="$output/$variant.index.json"
  jq -cs --arg revision "$revision" --arg version "$version" --arg image "docker.io/qualyticsai/ingress-nginx-$variant" '
    {schemaVersion: 2, mediaType: "application/vnd.oci.image.index.v1+json",
     manifests: [.[].manifests[]],
     annotations: {"org.opencontainers.image.revision": $revision, "org.opencontainers.image.version": $version,
                   "org.opencontainers.image.ref.name": $image, "org.opencontainers.image.source": "https://github.com/Qualytics/ingress-nginx"}}
  ' "$layout/amd64.index" "$layout/arm64.index" > "$index"
  sha=$(shasum -a 256 "$index" | cut -d ' ' -f 1)
  cp "$index" "$layout/blobs/sha256/$sha"
  jq -n --arg digest "sha256:$sha" --argjson size "$(wc -c < "$index")" '
    {schemaVersion: 2, manifests: [{mediaType: "application/vnd.oci.image.index.v1+json", digest: $digest, size: $size,
      annotations: {"org.opencontainers.image.ref.name": "qualified"}}]}
  ' > "$layout/index.json"
done
