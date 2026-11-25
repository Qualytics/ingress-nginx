variable "VERSION" {
  default = "local"
}

variable "COMMIT_SHA" {
  default = "working-tree"
}

variable "IMAGE" {
  default = "docker.io/qualyticsai/ingress-nginx-controller"
}

target "nginx-base" {
  context = "images/nginx/rootfs"
}

target "binaries" {
  context    = "."
  dockerfile = "build/controller-binaries.Dockerfile"
  args = {
    VERSION    = VERSION
    COMMIT_SHA = COMMIT_SHA
  }
}

target "controller" {
  context = "rootfs"
  contexts = {
    qualytics-nginx-base = "target:nginx-base"
    qualytics-binaries   = "target:binaries"
  }
  args = {
    BASE_IMAGE    = "qualytics-nginx-base"
    BINARY_SOURCE = "qualytics-binaries"
    VERSION       = VERSION
    COMMIT_SHA    = COMMIT_SHA
  }
  tags = ["${IMAGE}:${VERSION}"]
}

target "controller-chroot" {
  inherits   = ["controller"]
  dockerfile = "Dockerfile-chroot"
  tags       = ["${IMAGE}-chroot:${VERSION}"]
}
