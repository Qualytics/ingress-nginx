# Copyright 2024 The Kubernetes Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
ARG ALPINE_IMAGE=docker.io/library/alpine:3.23.8@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2
FROM ${ALPINE_IMAGE} AS native-build
ARG BUILD_JOBS=4
ENV SUDO="" PACKAGER="Qualytics <hello@qualytics.ai>"
RUN apk add --no-cache alpine-sdk abuild abseil-cpp-dev cmake ninja c-ares-dev re2-dev \
    openssl openssl-dev zlib-dev linux-headers gtest-dev \
    && abuild-keygen -a -i -n
COPY native/protobuf /src/native/protobuf
RUN cd /src/native/protobuf && abuild -F fetch verify
# Build only with the signed system dependencies and verified source already installed.
RUN --network=none cd /src/native/protobuf && JOBS="$BUILD_JOBS" abuild -F -d -P /packages \
    && apk add --no-network /packages/native/*/protobuf*.apk
COPY native/grpc /src/native/grpc
RUN cd /src/native/grpc && abuild -F fetch verify
RUN --network=none cd /src/native/grpc && JOBS="$BUILD_JOBS" abuild -F -d -P /packages
RUN mkdir /out && cp /packages/native/*/*.apk /out/ \
    && cp /root/.abuild/*.rsa.pub /out/

FROM scratch AS native-packages
COPY --from=native-build /out/ /

FROM ${ALPINE_IMAGE} AS builder
ARG BUILD_JOBS

COPY build.sh opentelemetry-nginx.cmake /
COPY patches /patches

RUN --mount=type=bind,from=native-packages,target=/packages/native \
  cp /packages/native/*.rsa.pub /etc/apk/keys/ \
  && apk add --no-cache /packages/native/*.apk \
  && apk update \
  && apk upgrade \
  && apk add -U bash --no-cache \
  && /build.sh

# Use a multi-stage build
FROM ${ALPINE_IMAGE}

ENV PATH=$PATH:/usr/local/luajit/bin:/usr/local/nginx/sbin:/usr/local/nginx/bin

ENV LUA_PATH="/usr/local/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/lib/lua/?.lua;;"
ENV LUA_CPATH="/usr/local/lib/lua/?/?.so;/usr/local/lib/lua/?.so;;"

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib/libopentelemetry* /usr/local/lib
COPY --from=builder /opt /opt
COPY --from=builder /etc/nginx /etc/nginx

RUN --mount=type=bind,source=libxml2,target=/packages/libxml2 \
  --mount=type=bind,from=native-packages,target=/packages/native \
  cp /packages/native/*.rsa.pub /etc/apk/keys/ \
  && apk update \
  && apk upgrade \
  && apk add -U --no-cache \
  bash \
  openssl \
  pcre \
  pcre2 \
  zlib \
  ca-certificates \
  patch \
  yajl \
  lmdb \
  libmaxminddb \
  yaml-cpp \
  dumb-init \
  tzdata \
  /packages/native/grpc-[0-9]*.apk \
  /packages/native/protobuf-[0-9]*.apk \
  abseil-cpp-crc-cpu-detect \
  abseil-cpp-vlog-config-internal \
  && sh /packages/libxml2/install.sh / \
  && rm -f /etc/apk/keys/"$(basename /packages/native/*.rsa.pub)" \
  && ln -s /usr/local/nginx/sbin/nginx /sbin/nginx \
  && adduser -S -D -H -u 101 -h /usr/local/nginx \
  -s /sbin/nologin -G www-data -g www-data www-data \
  && bash -eu -c ' \
  writeDirs=( \
  /var/log/nginx \
  /var/lib/nginx/body \
  /var/lib/nginx/fastcgi \
  /var/lib/nginx/proxy \
  /var/lib/nginx/scgi \
  /var/lib/nginx/uwsgi \
  /var/log/audit \
  ); \
  for dir in "${writeDirs[@]}"; do \
  mkdir -p ${dir}; \
  chown -R www-data:www-data ${dir}; \
  done'

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
