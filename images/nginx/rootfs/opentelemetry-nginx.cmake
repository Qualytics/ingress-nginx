# The module should compile against the same patched NGINX tree as the controller.
if(NOT EXISTS "${NGINX_DIR}/objs/ngx_auto_config.h")
  message(FATAL_ERROR "A configured NGINX source tree is required")
endif()

add_custom_target(project_nginx)
set(NGINX_INCLUDE_DIRS
  "${NGINX_DIR}/objs"
  "${NGINX_DIR}/src/core"
  "${NGINX_DIR}/src/os/unix"
  "${NGINX_DIR}/src/event"
  "${NGINX_DIR}/src/event/quic"
  "${NGINX_DIR}/src/http"
  "${NGINX_DIR}/src/http/modules"
  "${NGINX_DIR}/src/http/v2"
  "${NGINX_DIR}/src/http/v3"
)
