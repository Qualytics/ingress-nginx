# Qualytics Ingress NGINX Controller

Qualytics brings together community and open-source maintenance work to provide an ingress controller for existing self-hosted deployments. It builds on the final Kubernetes ingress-nginx controller release with a maintained NGINX runtime, ModSecurity, and the OWASP Core Rule Set. [Upstream controller](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.15.1)

Qualytics publishes the `ingress-nginx` Helm chart at `https://qualytics.github.io/ingress-nginx`. The Qualytics self-hosted chart includes it as the optional `nginx` dependency. Existing installations keep their `nginx.*` values. [Standalone chart](charts/ingress-nginx/README.md) · [Self-hosted image inventory](https://github.com/Qualytics/qualytics-self-hosted/blob/main/docs/docker-images.md)

The chart pins the Linux amd64 and arm64 image indexes by digest. The controller and webhook helper share the private Docker Hub repository `qualyticsai/ingress-nginx-controller`. The chroot image also needs access to `qualyticsai/ingress-nginx-controller-chroot`. Each controller release publishes its signed indexes, Sigstore bundles and architecture-specific software bills of materials for independent verification. [Controller releases](https://github.com/Qualytics/ingress-nginx/releases) · [Signature verification](build/publish-controller.sh)

## Kubernetes support and installation

Qualytics ingress-nginx requires Kubernetes 1.35 or later. Upgrade older clusters before installing or upgrading to chart 4.15.3.

| Qualytics controller | Helm chart | Minimum Kubernetes | Tested Kubernetes minors |
|---|---|---|---|
| v1.30.8-qualytics.3 | 4.15.3 | 1.35 | 1.35, 1.36, 1.37 |

To install the standalone chart, first create an image pull Secret in the release namespace. The admission webhook uses it during installation. Substitute your Secret name for `regcred`.

```sh
helm repo add qualytics-ingress https://qualytics.github.io/ingress-nginx
helm repo update qualytics-ingress
helm upgrade --install ingress-nginx qualytics-ingress/ingress-nginx --version 4.15.3 \
  --namespace ingress-nginx --set 'imagePullSecrets[0].name=regcred'
```

## Overview

ingress-nginx is an Ingress controller for Kubernetes using [NGINX](https://www.nginx.org/) as a reverse proxy and load
balancer.

[Learn more about Ingress on the Kubernetes documentation site](https://kubernetes.io/docs/concepts/services-networking/ingress/).

## Usage warnings

Kubernetes retired the upstream project in March 2026 and recommends Gateway API for new installations. [Retirement notice](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)

Do not use in multi-tenant Kubernetes production installations. This project assumes that users that can create Ingress objects are administrators of the cluster. See the [FAQ](https://kubernetes.github.io/ingress-nginx/faq/#faq) for more.

## Troubleshooting

For a Qualytics deployment, contact Qualytics Support. Include the chart version, controller image digest, and Kubernetes version. For confidential security reports, see the [security policy](SECURITY.md).

## Changelog

Qualytics publishes chart packages in [Qualytics releases](https://github.com/Qualytics/ingress-nginx/releases). The earlier controller and chart history is available in [Kubernetes releases](https://github.com/kubernetes/ingress-nginx/releases).

### Historical upstream version matrix

These rows record test coverage and support status for upstream releases at the time they shipped. Current Qualytics releases follow the Kubernetes support table above.

| Supported | Ingress-NGINX version | k8s supported version         | Alpine Version | Nginx Version | Helm Chart Version |
| :-------: | --------------------- | ----------------------------- | -------------- | ------------- | ------------------ |
|    🔄     | **v1.15.1**           | 1.35, 1.34, 1.33, 1.32, 1.31  | 3.23.3         | 1.27.1        | 4.15.1             |
|    🔄     | **v1.15.0**           | 1.35, 1.34, 1.33, 1.32, 1.31  | 3.23.3         | 1.27.1        | 4.15.0             |
|    🔄     | **v1.14.5**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.3         | 1.27.1        | 4.14.5             |
|    🔄     | **v1.14.4**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.3         | 1.27.1        | 4.14.4             |
|    🔄     | **v1.14.3**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.2         | 1.27.1        | 4.14.3             |
|    🔄     | **v1.14.2**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.2         | 1.27.1        | 4.14.2             |
|    🔄     | **v1.14.1**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.22.2         | 1.27.1        | 4.14.1             |
|    🔄     | **v1.14.0**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.22.2         | 1.27.1        | 4.14.0             |
|    🔄     | **v1.13.9**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.3         | 1.27.1        | 4.13.9             |
|    🔄     | **v1.13.8**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.3         | 1.27.1        | 4.13.8             |
|    🔄     | **v1.13.7**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.2         | 1.27.1        | 4.13.7             |
|    🔄     | **v1.13.6**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.2         | 1.27.1        | 4.13.6             |
|    🔄     | **v1.13.5**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.2         | 1.27.1        | 4.13.5             |
|    🔄     | **v1.13.4**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.2         | 1.27.1        | 4.13.4             |
|    🔄     | **v1.13.3**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.3             |
|    🔄     | **v1.13.2**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.2             |
|    🔄     | **v1.13.1**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.1             |
|    🔄     | **v1.13.0**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.0         | 1.27.1        | 4.13.0             |
|           | v1.12.8               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.2         | 1.25.5        | 4.12.8             |
|           | v1.12.7               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.7             |
|           | v1.12.6               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.6             |
|           | v1.12.5               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.5             |
|           | v1.12.4               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.0         | 1.25.5        | 4.12.4             |
|           | v1.12.3               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.3             |
|           | v1.12.2               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.2             |
|           | v1.12.1               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.1             |
|           | v1.12.0               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.0         | 1.25.5        | 4.12.0             |
|           | v1.12.0-beta.0        | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.20.3         | 1.25.5        | 4.12.0-beta.0      |
|           | v1.11.8               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.22.0         | 1.25.5        | 4.11.8             |
|           | v1.11.7               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.7             |
|           | v1.11.6               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.6             |
|           | v1.11.5               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.5             |
|           | v1.11.4               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.0         | 1.25.5        | 4.11.4             |
|           | v1.11.3               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.3         | 1.25.5        | 4.11.3             |
|           | v1.11.2               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.2             |
|           | v1.11.1               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.1             |
|           | v1.11.0               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.0             |
|           | v1.10.6               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.0         | 1.25.5        | 4.10.6             |
|           | v1.10.5               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.3         | 1.25.5        | 4.10.5             |
|           | v1.10.4               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.4             |
|           | v1.10.3               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.3             |
|           | v1.10.2               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.2             |
|           | v1.10.1               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.19.1         | 1.25.3        | 4.10.1             |
|           | v1.10.0               | 1.29, 1.28, 1.27, 1.26        | 3.19.1         | 1.25.3        | 4.10.0             |
|           | v1.9.6                | 1.29, 1.28, 1.27, 1.26, 1.25  | 3.19.0         | 1.21.6        | 4.9.1              |
|           | v1.9.5                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.9.0              |
|           | v1.9.4                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.3              |
|           | v1.9.3                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.*              |
|           | v1.9.1                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.*              |
|           | v1.9.0                | 1.28, 1.27, 1.26, 1.25        | 3.18.2         | 1.21.6        | 4.8.*              |
|           | v1.8.4                | 1.27, 1.26, 1.25, 1.24        | 3.18.2         | 1.21.6        | 4.7.*              |
|           | v1.7.1                | 1.27, 1.26, 1.25, 1.24        | 3.17.2         | 1.21.6        | 4.6.*              |
|           | v1.6.4                | 1.26, 1.25, 1.24, 1.23        | 3.17.0         | 1.21.6        | 4.5.*              |
|           | v1.5.1                | 1.25, 1.24, 1.23              | 3.16.2         | 1.21.6        | 4.4.*              |
|           | v1.4.0                | 1.25, 1.24, 1.23, 1.22        | 3.16.2         | 1.19.10†      | 4.3.0              |
|           | v1.3.1                | 1.24, 1.23, 1.22, 1.21, 1.20  | 3.16.2         | 1.19.10†      | 4.2.5              |

See [Updating NGINX-Ingress to use the stable Ingress API (July 26, 2021)](https://kubernetes.io/blog/2021/07/26/update-with-ingress-nginx/)
to upgrade to the stable Ingress API before upgrading to Kubernetes 1.22.

## Get Involved

Thanks for taking the time to join our community and start contributing!

- This project adheres to the [Kubernetes Community Code of Conduct](https://git.k8s.io/community/code-of-conduct.md).
  By participating in this project, you agree to abide by its terms.
- **Contributing**: Documentation contributions are welcome.

  - Read [`CONTRIBUTING.md`](CONTRIBUTING.md) for information about the workflow that we
    expect and instructions on the developer certificate of origin that we require.

## License

[Apache License 2.0](https://github.com/kubernetes/ingress-nginx/blob/main/LICENSE)
