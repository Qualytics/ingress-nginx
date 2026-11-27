# Copyright 2021 The Kubernetes Authors. All rights reserved.
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

ARG GOLANG_VERSION=1.26.11
ARG GOLANG_DIGEST=sha256:ecb67f987aa1a57794c91d19ade7ae0209f2f0f5496aaef9e6ae85ddf92d02ab
FROM --platform=$BUILDPLATFORM docker.io/library/golang:${GOLANG_VERSION}-alpine@${GOLANG_DIGEST} AS builder
ARG GOLANG_VERSION
ENV GOTOOLCHAIN=local
WORKDIR /workspace
COPY go.mod go.sum ./
RUN test "$(go env GOVERSION)" = "go${GOLANG_VERSION}" && go mod download && go mod verify
COPY . .
ARG TARGETARCH
ARG VERSION=local
ARG BUILD_TIME=unknown
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH="$TARGETARCH" go build -mod=readonly -trimpath -buildvcs=false \
    -ldflags="-buildid= -s -w -X github.com/jet/kube-webhook-certgen/core.Version=$VERSION -X github.com/jet/kube-webhook-certgen/core.BuildTime=$BUILD_TIME" \
    -o /out/kube-webhook-certgen .

FROM scratch
ARG VERSION=local
ARG COMMIT_SHA=working-tree
LABEL org.opencontainers.image.source="https://github.com/Qualytics/ingress-nginx" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$COMMIT_SHA"
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /out/kube-webhook-certgen /kube-webhook-certgen
COPY LICENSE /usr/share/licenses/kube-webhook-certgen/LICENSE
USER 65532:65532
ENTRYPOINT ["/kube-webhook-certgen"]
