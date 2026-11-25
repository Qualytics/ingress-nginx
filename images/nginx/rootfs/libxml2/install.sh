#!/bin/sh
set -eu

# Alpine's signed edge/main APKs carry the upstream fixes and preserve libxml2.so.2.
# https://github.com/alpinelinux/aports/commit/e3071fe8f7dc214608fdc5c7b65756cb552eaa42
root=$1
cd /packages/libxml2
sha256sum -c SHA256SUMS
apk --root "$root" --initdb --no-cache --no-scripts \
    --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories \
    add "$PWD/$(apk --print-arch)/libxml2-2.13.9-r4.apk"
install -Dm644 Copyright "$root/usr/share/licenses/libxml2/Copyright"
