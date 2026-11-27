#!/usr/bin/env bash
set -euo pipefail

candidate=${1:?pass a locally loaded controller image}
case ${2:?pass the controller variant} in
  controller) root=/ ;;
  controller-chroot) root=/chroot ;;
  *) exit 2 ;;
esac

work=$(mktemp -d)
collector=
proxy=
cleanup() {
  if [[ $? != 0 ]]; then
    if [[ -n "$collector" ]]; then docker logs "$collector" >&2; fi
    if [[ -n "$proxy" ]]; then docker logs "$proxy" >&2; fi
  fi
  if [[ -n "$proxy" ]]; then docker rm -f "$proxy" >/dev/null; fi
  if [[ -n "$collector" ]]; then docker rm -f "$collector" >/dev/null; fi
  rm -rf "$work"
}
trap cleanup EXIT

cat > "$work/collector.yaml" <<'YAML'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 127.0.0.1:4317
exporters:
  debug:
    verbosity: detailed
service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [debug]
YAML
cat > "$work/otel.toml" <<'TOML'
exporter = "otlp"
processor = "simple"
[exporters.otlp]
host = "127.0.0.1"
port = 4317
[service]
name = "qualytics-ingress-check"
[sampler]
name = "AlwaysOn"
TOML
cat > "$work/nginx.conf" <<'NGINX'
load_module /etc/nginx/modules/otel_ngx_module.so;
pid /tmp/nginx-otel-check.pid;
error_log stderr;
events {}
http {
  opentelemetry_config /tmp/otel.toml;
  server {
    listen 127.0.0.1:8080;
    location / {
      opentelemetry on;
      opentelemetry_operation_name qualytics-otlp-roundtrip;
      return 200 "ok";
    }
  }
}
NGINX

collector=$(docker run -d --network none -v "$work/collector.yaml:/collector.yaml:ro" \
  ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:0.166.0@sha256:5dfb40297a8da893e4e9b6b98d3ddbdd9082f73611170d6381e355e08b235334 \
  --config=/collector.yaml)
proxy=$(docker run -d --network "container:$collector" --user 0 --entrypoint chroot \
  -v "$work/nginx.conf:${root%/}/tmp/nginx.conf:ro" -v "$work/otel.toml:${root%/}/tmp/otel.toml:ro" \
  "$candidate" "$root" /usr/local/nginx/sbin/nginx -c /tmp/nginx.conf -g 'daemon off;')

for ((attempt=0; attempt<30; attempt++)); do
  if [[ $(docker exec "$proxy" wget -T 2 -qO- http://127.0.0.1:8080/) == ok ]]; then
    logs=$(docker logs "$collector" 2>&1)
    if grep -Fq 'service.name: Str(qualytics-ingress-check)' <<< "$logs" &&
       grep -Eq 'Name[[:space:]]*:[[:space:]]*qualytics-otlp-roundtrip([[:space:]]|$)' <<< "$logs"; then
      echo "Collector received the NGINX qualification span from $candidate"
      exit 0
    fi
  fi
  sleep 1
done
echo "Collector did not receive the NGINX qualification span" >&2
exit 1
