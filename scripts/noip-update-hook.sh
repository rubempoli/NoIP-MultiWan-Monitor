#!/usr/bin/env bash
# No-IP DUC exec-on-change hook
# Author: Rubem Swensson
# Co-Authors: ChatGPT + Codex
# Changelog:
# - 2026-05-17: Preserved generic No-IP DDNS status fields during DUC hook updates.
# - 2026-05-17: Preserved consolidated previous public IP when DUC LAST_IP is empty or invalid.
# - 2026-05-17: Refactored hook to update consolidated status and append audit history.

set -euo pipefail

CONFIG_FILE="${NOIP_MONITOR_CONFIG:-/etc/noip-monitor.conf}"

NOIP_HOSTNAME="${NOIP_HOSTNAME:-realswensson.ddns.net}"
STATUS_DIR="${STATUS_DIR:-/var/lib/noip}"
STATUS_FILE="${STATUS_FILE:-${STATUS_DIR}/status.txt}"
HISTORY_FILE="${HISTORY_FILE:-${STATUS_DIR}/history.log}"
UNKNOWN_ISP_LABEL="${UNKNOWN_ISP_LABEL:-unknown}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

now_iso() {
  date -Iseconds
}

status_value() {
  local key="$1"
  local default_value="${2:-}"
  local value=""
  if [[ -f "$STATUS_FILE" ]]; then
    value="$(grep -m1 "^${key}=" "$STATUS_FILE" | cut -d= -f2- || true)"
  fi
  printf '%s\n' "${value:-$default_value}"
}

atomic_write_status() {
  local tmp_file
  tmp_file="$(mktemp "${STATUS_DIR}/status.XXXXXX")"
  cat > "$tmp_file"
  chmod 0644 "$tmp_file"
  mv "$tmp_file" "$STATUS_FILE"
}

main() {
  mkdir -p "$STATUS_DIR"
  touch "$HISTORY_FILE"

  if [[ -z "${CURRENT_IP:-}" ]]; then
    echo "ERROR: CURRENT_IP is empty" >&2
    exit 1
  fi

  local hook_time
  local duc_previous_ip
  local consolidated_previous_ip
  local current_status_ip
  local previous_public_ip
  local published_dns_ip
  local dns_status
  local noip_ddns_01_name
  local noip_ddns_01_hostname
  local noip_ddns_01_public_ip
  local noip_ddns_02_name
  local noip_ddns_02_hostname
  local noip_ddns_02_public_ip
  local noip_ddns_03_name
  local noip_ddns_03_hostname
  local noip_ddns_03_public_ip
  local current_isp
  local previous_isp
  local last_check
  local last_ip_change
  local last_duc_restart_trigger
  local append_line

  hook_time="$(now_iso)"
  duc_previous_ip="${LAST_IP:-unknown}"
  consolidated_previous_ip="$(status_value "PREVIOUS_PUBLIC_IP" "unknown")"
  current_status_ip="$(status_value "CURRENT_PUBLIC_IP" "$(status_value "CURRENT_IP" "unknown")")"
  previous_public_ip="$duc_previous_ip"

  if [[ -z "$previous_public_ip" || "$previous_public_ip" == "unknown" || "$previous_public_ip" == "0.0.0.0" ]]; then
    previous_public_ip="$consolidated_previous_ip"
  fi

  if [[ -z "$previous_public_ip" || "$previous_public_ip" == "unknown" ]]; then
    previous_public_ip="$current_status_ip"
  fi

  published_dns_ip="$(status_value "PUBLISHED_DNS_IP" "unknown")"
  dns_status="$(status_value "DNS_STATUS" "UNKNOWN")"
  noip_ddns_01_name="$(status_value "NOIP_DDNS_01_NAME" "")"
  noip_ddns_01_hostname="$(status_value "NOIP_DDNS_01_HOSTNAME" "")"
  noip_ddns_01_public_ip="$(status_value "NOIP_DDNS_01_PUBLIC_IP" "unknown")"
  noip_ddns_02_name="$(status_value "NOIP_DDNS_02_NAME" "")"
  noip_ddns_02_hostname="$(status_value "NOIP_DDNS_02_HOSTNAME" "")"
  noip_ddns_02_public_ip="$(status_value "NOIP_DDNS_02_PUBLIC_IP" "unknown")"
  noip_ddns_03_name="$(status_value "NOIP_DDNS_03_NAME" "")"
  noip_ddns_03_hostname="$(status_value "NOIP_DDNS_03_HOSTNAME" "")"
  noip_ddns_03_public_ip="$(status_value "NOIP_DDNS_03_PUBLIC_IP" "unknown")"
  current_isp="$(status_value "CURRENT_ISP" "$UNKNOWN_ISP_LABEL")"
  previous_isp="$(status_value "PREVIOUS_ISP" "$UNKNOWN_ISP_LABEL")"
  last_check="$(status_value "LAST_CHECK" "$hook_time")"
  last_ip_change="$(status_value "LAST_IP_CHANGE" "$hook_time")"
  last_duc_restart_trigger="$(status_value "LAST_DUC_RESTART_TRIGGER" "")"

  append_line="${hook_time} | DUC_HOOK_UPDATE | CURRENT_IP=${CURRENT_IP} | PREVIOUS_IP=${previous_public_ip} | LAST_IP_FROM_DUC=${duc_previous_ip}"
  printf '%s\n' "$append_line" >> "$HISTORY_FILE"

  atomic_write_status <<EOF
HOSTNAME=${NOIP_HOSTNAME}
CURRENT_PUBLIC_IP=${CURRENT_IP}
PUBLISHED_DNS_IP=${published_dns_ip}
DNS_STATUS=${dns_status}
NOIP_DDNS_01_NAME=${noip_ddns_01_name}
NOIP_DDNS_01_HOSTNAME=${noip_ddns_01_hostname}
NOIP_DDNS_01_PUBLIC_IP=${noip_ddns_01_public_ip}
NOIP_DDNS_02_NAME=${noip_ddns_02_name}
NOIP_DDNS_02_HOSTNAME=${noip_ddns_02_hostname}
NOIP_DDNS_02_PUBLIC_IP=${noip_ddns_02_public_ip}
NOIP_DDNS_03_NAME=${noip_ddns_03_name}
NOIP_DDNS_03_HOSTNAME=${noip_ddns_03_hostname}
NOIP_DDNS_03_PUBLIC_IP=${noip_ddns_03_public_ip}
CURRENT_ISP=${current_isp}
PREVIOUS_PUBLIC_IP=${previous_public_ip}
PREVIOUS_ISP=${previous_isp}
LAST_CHECK=${last_check}
LAST_IP_CHANGE=${last_ip_change}
LAST_DUC_HOOK_UPDATE=${hook_time}
LAST_DUC_RESTART_TRIGGER=${last_duc_restart_trigger}
LAST_IP_FROM_DUC=${duc_previous_ip}
EOF
}

main "$@"
