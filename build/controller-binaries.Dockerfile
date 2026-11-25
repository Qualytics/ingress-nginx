FROM docker.io/library/golang:1.26.11-alpine@sha256:ecb67f987aa1a57794c91d19ade7ae0209f2f0f5496aaef9e6ae85ddf92d02ab AS build
WORKDIR /src
ENV GOTOOLCHAIN=local
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY build/build.sh build/build.sh
COPY cmd cmd
COPY internal internal
COPY pkg pkg
COPY version version
ARG TARGETARCH
ARG VERSION
ARG COMMIT_SHA
RUN --mount=type=cache,target=/root/.cache/go-build \
    mkdir -p "rootfs/bin/$TARGETARCH" && \
    PKG=k8s.io/ingress-nginx ARCH="$TARGETARCH" TAG="$VERSION" COMMIT_SHA="$COMMIT_SHA" \
    REPO_INFO=https://github.com/Qualytics/ingress-nginx ./build/build.sh \
    && mv "rootfs/bin/$TARGETARCH" /binaries

FROM scratch
COPY --from=build /binaries/ /
