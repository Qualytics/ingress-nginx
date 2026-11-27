#!/usr/bin/env bash

controller_images=(controller controller-chroot controller-webhook-certgen)

controller_image_ref() {
  local variant=$1 version=$2
  case "$variant" in
    controller|controller-chroot) printf 'docker.io/qualyticsai/ingress-nginx-%s:%s\n' "$variant" "$version" ;;
    controller-webhook-certgen) printf 'docker.io/qualyticsai/ingress-nginx-controller:kube-webhook-certgen-%s\n' "$version" ;;
    *) echo "Unknown release image: $variant" >&2; return 1 ;;
  esac
}
