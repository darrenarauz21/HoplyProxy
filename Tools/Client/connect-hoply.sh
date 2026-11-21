#!/usr/bin/env bash
# Conecta la laptop (macOS o Linux) con Hoply en el iPhone.
# En modo USB inicia el reenvío de go-ios. Con --system-proxy configura el proxy automático
# del sistema mientras el script esté activo y lo restaura al salir (Ctrl+C).

set -euo pipefail

readonly VERIFY_URL="https://ifconfig.me"
readonly FORWARD_STARTUP_SECONDS=2

mode="usb"
port="1080"
host=""
configure_system_proxy=0
macos_service="Wi-Fi"

forward_pid=""
restore_system_proxy=""

usage() {
  cat <<'USAGE'
Uso: connect-hoply.sh [opciones]

  --mode usb|wifi     Conexión con el iPhone (por defecto: usb).
  --port PUERTO       Puerto configurado en la app, 1024-65535 (por defecto: 1080).
  --host IP           IP del iPhone que muestra la app. Obligatoria en modo wifi.
  --system-proxy      Configura el proxy automático del sistema mientras el script esté activo.
  --service NOMBRE    Servicio de red de macOS para --system-proxy (por defecto: Wi-Fi).
  -h, --help          Muestra esta ayuda.
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

is_valid_port() {
  [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1024 && 10#$1 <= 65535 ))
}

is_valid_ipv4() {
  local IFS=.
  local -a octets
  [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  read -r -a octets <<< "$1"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done
}

parse_arguments() {
  while (( $# > 0 )); do
    case "$1" in
      --mode) mode="${2:-}"; shift 2 ;;
      --port) port="${2:-}"; shift 2 ;;
      --host) host="${2:-}"; shift 2 ;;
      --system-proxy) configure_system_proxy=1; shift ;;
      --service) macos_service="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; fail "opción desconocida: $1" ;;
    esac
  done

  is_valid_port "$port" || fail "el puerto debe estar entre 1024 y 65535."
  case "$mode" in
    usb) host="127.0.0.1" ;;
    wifi) is_valid_ipv4 "$host" || fail "en modo wifi indica la IP del iPhone con --host." ;;
    *) fail "el modo debe ser usb o wifi." ;;
  esac
}

cleanup() {
  if [[ -n "$restore_system_proxy" ]]; then
    eval "$restore_system_proxy" || echo "No se pudo restaurar el proxy del sistema." >&2
  fi
  if [[ -n "$forward_pid" ]] && kill -0 "$forward_pid" 2>/dev/null; then
    kill "$forward_pid" 2>/dev/null || true
  fi
}

start_usb_forward() {
  command -v ios >/dev/null 2>&1 || fail "no se encontró go-ios. Instálalo con: npm install -g go-ios"
  ios forward "$port" "$port" &
  forward_pid=$!
  sleep "$FORWARD_STARTUP_SECONDS"
  kill -0 "$forward_pid" 2>/dev/null || fail "el reenvío USB terminó. Comprueba el cable y que el iPhone confíe en esta laptop."
}

set_macos_proxy() {
  local pac_url="$1" previous_url previous_state
  previous_url="$(networksetup -getautoproxyurl "$macos_service" | sed -n 's/^URL: //p')"
  previous_state="$(networksetup -getautoproxyurl "$macos_service" | sed -n 's/^Enabled: //p')"
  networksetup -setautoproxyurl "$macos_service" "$pac_url"
  if [[ "$previous_state" == "Yes" && -n "$previous_url" && "$previous_url" != "(null)" ]]; then
    restore_system_proxy="networksetup -setautoproxyurl $(printf '%q %q' "$macos_service" "$previous_url")"
  else
    restore_system_proxy="networksetup -setautoproxystate $(printf '%q' "$macos_service") off"
  fi
}

set_gnome_proxy() {
  local pac_url="$1" previous_mode previous_url
  command -v gsettings >/dev/null 2>&1 || fail "--system-proxy en Linux requiere GNOME (gsettings)."
  previous_mode="$(gsettings get org.gnome.system.proxy mode)"
  previous_url="$(gsettings get org.gnome.system.proxy autoconfig-url)"
  gsettings set org.gnome.system.proxy autoconfig-url "$pac_url"
  gsettings set org.gnome.system.proxy mode "'auto'"
  restore_system_proxy="gsettings set org.gnome.system.proxy autoconfig-url $(printf '%q' "$previous_url"); gsettings set org.gnome.system.proxy mode $(printf '%q' "$previous_mode")"
}

configure_proxy() {
  local pac_url="http://${host}:${port}/proxy.pac"
  case "$(uname -s)" in
    Darwin) set_macos_proxy "$pac_url" ;;
    Linux) set_gnome_proxy "$pac_url" ;;
    *) fail "--system-proxy no está disponible en este sistema." ;;
  esac
  echo "Proxy automático del sistema configurado: $pac_url"
}

print_environment() {
  cat <<ENV

Para usar el proxy en otra terminal, ejecuta:
  export http_proxy=http://${host}:${port} https_proxy=http://${host}:${port} ALL_PROXY=socks5h://${host}:${port}
ENV
}

verify_connection() {
  local address
  if address="$(curl --silent --show-error --max-time 15 --proxy "http://${host}:${port}" "$VERIFY_URL")"; then
    echo "Conectado. IP pública a través del iPhone: $address"
  else
    echo "No se pudo verificar la conexión. Comprueba que el proxy esté activo en la app." >&2
  fi
}

main() {
  parse_arguments "$@"
  trap cleanup EXIT
  trap 'exit 130' INT TERM

  [[ "$mode" == "usb" ]] && start_usb_forward
  (( configure_system_proxy )) && configure_proxy
  verify_connection
  print_environment

  echo
  echo "Pulsa Ctrl+C para desconectar."
  if [[ -n "$forward_pid" ]]; then
    wait "$forward_pid" || true
    echo "El reenvío USB terminó." >&2
  else
    while true; do sleep 60; done
  fi
}

main "$@"
