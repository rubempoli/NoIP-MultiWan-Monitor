#!/usr/bin/env bash
# noip-multiwan-monitor periodic monitor
# Author: Rubem Swensson
# Co-Authors: ChatGPT + Codex
# Changelog:
# - 2026-05-17: Renamed visible project references to multi-WAN.
# - 2026-05-17: Initial monitor with public IP, DNS consistency, ISP detection, history, and optional DUC restart.

set -euo pipefail

CONFIG_FILE="${NOIP_MONITOR_CONFIG:-/etc/noip-monitor.conf}"

NOIP_HOSTNAME="${NOIP_HOSTNAME:-realswensson.ddns.net}"
STATUS_DIR="${STATUS_DIR:-/var/lib/noip}"
STATUS_FILE="${STATUS_FILE:-${STATUS_DIR}/status.txt}"
HISTORY_FILE="${HISTORY_FILE:-${STATUS_DIR}/history.log}"
PUBLIC_IP_ENDPOINTS="${PUBLIC_IP_ENDPOINTS:-http://ip1.dynupdate.no-ip.com:8245 https://api.ipify.org}"
PUBLIC_IP_TIMEOUT_SECONDS="${PUBLIC_IP_TIMEOUT_SECONDS:-10}"
DNS_RESOLVER="${DNS_RESOLVER:-1.1.1.1}"
ISP_PREFIX_RULES="${ISP_PREFIX_RULES:-}"
UNKNOWN_ISP_LABEL="${UNKNOWN_ISP_LABEL:-unknown}"
ENABLE_DUC_RESTART="${ENABLE_DUC_RESTART:-false}"
DUC_SERVICE_NAME="${DUC_SERVICE_NAME:-noip-duc.service}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command_name" >&2
    exit 1
  fi
}

now_iso() {
  date -Iseconds
}

is_ipv4() {
  local value="$1"
  [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
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

append_history() {
  local event_time="$1"
  local event_type="$2"
  shift 2
  printf '%s | %s' "$event_time" "$event_type" >> "$HISTORY_FILE"
  for field in "$@"; do
    printf ' | %s' "$field" >> "$HISTORY_FILE"
  done
  printf '\n' >> "$HISTORY_FILE"
}

get_public_ip() {
  local endpoint
  local response
  for endpoint in $PUBLIC_IP_ENDPOINTS; do
    response="$(curl -fsS --max-time "$PUBLIC_IP_TIMEOUT_SECONDS" "$endpoint" 2>/dev/null | tr -d '[:space:]' || true)"
    if is_ipv4 "$response"; then
      printf '%s\n' "$response"
      return 0
    fi
  done
  return 1
}

get_published_dns_ip() {
  local dns_ip
  dns_ip="$(dig +short "$NOIP_HOSTNAME" @"$DNS_RESOLVER" | grep -m1 -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true)"
  if [[ -n "$dns_ip" ]]; then
    printf '%s\n' "$dns_ip"
    return 0
  fi
  return 1
}

detect_isp() {
  local ip_address="$1"
  local rule
  local provider
  local prefixes
  local prefix
  local -a rules
  local -a prefix_list

  IFS=';' read -ra rules <<< "$ISP_PREFIX_RULES"
  for rule in "${rules[@]}"; do
    [[ -z "$rule" || "$rule" != *=* ]] && continue
    provider="${rule%%=*}"
    prefixes="${rule#*=}"
    IFS=',' read -ra prefix_list <<< "$prefixes"
    for prefix in "${prefix_list[@]}"; do
      [[ -z "$prefix" ]] && continue
      if [[ "$ip_address" == "$prefix"* ]]; then
        printf '%s\n' "$provider"
        return 0
      fi
    done
  done

  printf '%s\n' "$UNKNOWN_ISP_LABEL"
}

atomic_write_status() {
  local tmp_file
  tmp_file="$(mktemp "${STATUS_DIR}/status.XXXXXX")"
  cat > "$tmp_file"
  chmod 0644 "$tmp_file"
  mv "$tmp_file" "$STATUS_FILE"
}

maybe_restart_duc() {
  local event_time="$1"
  if [[ "${ENABLE_DUC_RESTART,,}" != "true" ]]; then
    return 0
  fi

  require_command systemctl
  systemctl restart "$DUC_SERVICE_NAME"
  append_history "$event_time" "DUC_RESTART_TRIGGER" "SERVICE=${DUC_SERVICE_NAME}"
}

main() {
  require_command curl
  require_command dig

  mkdir -p "$STATUS_DIR"
  touch "$HISTORY_FILE"

  local check_time
  local current_public_ip
  local published_dns_ip
  local dns_status
  local current_isp
  local previous_public_ip
  local previous_isp
  local last_ip_change
  local last_duc_hook_update
  local last_duc_restart_trigger
  local dns_event_state
  local previous_dns_status

  check_time="$(now_iso)"
  current_public_ip="$(get_public_ip)" || {
    append_history "$check_time" "ERROR" "MESSAGE=Could not determine current public IP"
    echo "ERROR: Could not determine current public IP" >&2
    exit 1
  }

  published_dns_ip="$(get_published_dns_ip || true)"
  current_isp="$(detect_isp "$current_public_ip")"

  previous_public_ip="$(status_value "CURRENT_PUBLIC_IP" "$(status_value "CURRENT_IP" "unknown")")"
  previous_isp="$(status_value "CURRENT_ISP" "$UNKNOWN_ISP_LABEL")"
  last_ip_change="$(status_value "LAST_IP_CHANGE" "")"
  last_duc_hook_update="$(status_value "LAST_DUC_HOOK_UPDATE" "")"
  last_duc_restart_trigger="$(status_value "LAST_DUC_RESTART_TRIGGER" "")"
  previous_dns_status="$(status_value "DNS_STATUS" "UNKNOWN")"

  if [[ -z "$published_dns_ip" ]]; then
    published_dns_ip="unknown"
    dns_status="UNKNOWN"
  elif [[ "$published_dns_ip" == "$current_public_ip" ]]; then
    dns_status="OK"
  else
    dns_status="DIVERGENT"
  fi

  if [[ "$previous_public_ip" != "$current_public_ip" && "$previous_public_ip" != "unknown" && -n "$previous_public_ip" ]]; then
    last_ip_change="$check_time"
    append_history "$check_time" "IP_CHANGE" "ISP=${current_isp}" "OLD_IP=${previous_public_ip}" "NEW_IP=${current_public_ip}" "PREVIOUS_ISP=${previous_isp}"
    if [[ "${ENABLE_DUC_RESTART,,}" == "true" ]]; then
      maybe_restart_duc "$check_time"
      last_duc_restart_trigger="$check_time"
    fi
  elif [[ -z "$last_ip_change" ]]; then
    last_ip_change="$check_time"
  fi

  if [[ "$previous_dns_status" != "$dns_status" ]]; then
    dns_event_state="DNS_IP=${published_dns_ip}"
    append_history "$check_time" "DNS_STATUS" "$dns_status" "$dns_event_state"
  fi

  atomic_write_status <<EOF
HOSTNAME=${NOIP_HOSTNAME}
CURRENT_PUBLIC_IP=${current_public_ip}
PUBLISHED_DNS_IP=${published_dns_ip}
DNS_STATUS=${dns_status}
CURRENT_ISP=${current_isp}
PREVIOUS_PUBLIC_IP=${previous_public_ip}
PREVIOUS_ISP=${previous_isp}
LAST_CHECK=${check_time}
LAST_IP_CHANGE=${last_ip_change}
LAST_DUC_HOOK_UPDATE=${last_duc_hook_update}
LAST_DUC_RESTART_TRIGGER=${last_duc_restart_trigger}
EOF
}

main "$@"
