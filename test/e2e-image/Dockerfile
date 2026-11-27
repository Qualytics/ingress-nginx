ARG E2E_BASE_IMAGE
FROM registry.k8s.io/kubectl:v1.36.7@sha256:3f2cf571aa96e47b5df0c4770aef92322e9c6542ca8c3c412a5cb6c108a24ecc AS kubectl
FROM ${E2E_BASE_IMAGE} AS chart-runner
COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl

FROM alpine:3.23.3

RUN apk update \
	&& apk upgrade && apk add -U --no-cache \
  ca-certificates \
  bash \
  tzdata \
  libc6-compat \
  openssl \
  sqlite-dev

COPY --from=chart-runner /go/bin/ginkgo /usr/local/bin/
COPY --from=chart-runner /usr/local/bin/helm /usr/local/bin/
COPY --from=chart-runner /usr/local/bin/kubectl /usr/local/bin/
COPY --from=chart-runner /usr/bin/cfssl /usr/local/bin/
COPY --from=chart-runner /usr/bin/cfssljson /usr/local/bin/

COPY . /

CMD [ "/e2e.sh" ]
