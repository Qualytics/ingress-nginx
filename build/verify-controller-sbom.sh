#!/usr/bin/env bash
set -euo pipefail

metadata=${1:?pass the release metadata directory}
variant=${2:?pass the controller variant}
arch=${3:?pass the Linux architecture}
version=${4:?pass the release version}
index="$metadata/$variant.index.json"
manifest="$metadata/$variant-$arch.attestation.json"
sbom="$metadata/$variant-$arch.spdx.intoto.json"
source=https://github.com/Qualytics/ingress-nginx

cosign verify-blob --bundle "$metadata/$variant.sigstore.json" \
  --certificate-identity "$source/.github/workflows/qualytics-controller.yml@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com "$index" >&2
jq -e --arg image "docker.io/qualyticsai/ingress-nginx-$variant" --arg version "$version" '
  .annotations["org.opencontainers.image.ref.name"] == $image and
  .annotations["org.opencontainers.image.version"] == $version
' "$index" >/dev/null
runnable=$(jq -er --arg arch "$arch" '.manifests[] | select(.platform.os == "linux" and .platform.architecture == $arch) | .digest' "$index")
attestation=$(jq -er --arg digest "$runnable" '.manifests[] | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest" and .annotations["vnd.docker.reference.digest"] == $digest) | .digest' "$index")
printf '%s  %s\n' "${attestation#sha256:}" "$manifest" | shasum -a 256 -c >&2
layer=$(jq -er '.layers[] | select(.annotations["in-toto.io/predicate-type"] == "https://spdx.dev/Document") | .digest' "$manifest")
printf '%s  %s\n' "${layer#sha256:}" "$sbom" | shasum -a 256 -c >&2
jq -e '.predicate | select(.spdxVersion | startswith("SPDX-"))' "$sbom"
