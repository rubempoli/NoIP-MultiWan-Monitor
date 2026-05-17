#!/usr/bin/env bash
# Manual DNS consistency check
# Author: Rubem Swensson
# Co-Authors: ChatGPT + Codex
# Changelog:
# - 2026-05-17: Updated check to use consolidated CURRENT_PUBLIC_IP and PUBLISHED_DNS_IP concepts.

set -euo pipefail

CONFIG_FILE="${NOIP_MONITOR_CONFIG:-/etc/noip-monitor.conf}"

NOIP_HOSTNAME="${NOIP_HOSTNAME:-realswensson.ddns.net}"
STATUS_DIR="${STATUS_DIR:-/var/lib/noip}"
STATUS_FILE="${STATUS_FILE:-${STATUS_DIR}/status.txt}"
DNS_RESOLVER="${DNS_RESOLVER:-1.1.1.1}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

status_value() {
  local key="$1"
  grep -m1 "^${key}=" "$STATUS_FILE" | cut -d= -f2- || true
}

main() {
  local current_public_ip
  local published_dns_ip

  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "UNKNOWN STATUS_FILE=${STATUS_FILE}"
    exit 2
  fi

  current_public_ip="$(status_value "CURRENT_PUBLIC_IP")"
  published_dns_ip="$(dig +short "$NOIP_HOSTNAME" @"$DNS_RESOLVER" | grep -m1 -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true)"

  if [[ -z "$current_public_ip" || -z "$published_dns_ip" ]]; then
    echo "UNKNOWN CURRENT_PUBLIC_IP=${current_public_ip:-unknown} PUBLISHED_DNS_IP=${published_dns_ip:-unknown}"
    exit 2
  fi

  if [[ "$published_dns_ip" == "$current_public_ip" ]]; then
    echo "OK CURRENT_PUBLIC_IP=${current_public_ip} PUBLISHED_DNS_IP=${published_dns_ip}"
  else
    echo "DIVERGENT CURRENT_PUBLIC_IP=${current_public_ip} PUBLISHED_DNS_IP=${published_dns_ip}"
    exit 1
  fi
}

main "$@"
