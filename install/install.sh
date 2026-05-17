#!/usr/bin/env bash
# Conservative installer for noip-dualwan-monitor
# Author: Rubem Swensson
# Co-Authors: ChatGPT + Codex
# Changelog:
# - 2026-05-17: Initial installer with backups and no blind overwrite of existing runtime files.

set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="${PROJECT_ROOT}/config/noip-monitor.conf.example"
CONFIG_TARGET="${CONFIG_TARGET:-/etc/noip-monitor.conf}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
STATUS_DIR="${STATUS_DIR:-/var/lib/noip}"
DUC_ENV_FILE="${DUC_ENV_FILE:-/etc/noip-duc.env}"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This installer must run as root." >&2
    exit 1
  fi
}

install_file() {
  local source_file="$1"
  local target_file="$2"
  local mode="$3"

  if [[ -f "$target_file" ]]; then
    cp -p "$target_file" "${target_file}.backup-${BACKUP_SUFFIX}"
  fi

  install -m "$mode" "$source_file" "$target_file"
}

main() {
  require_root

  install -d -m 0755 "$STATUS_DIR"
  touch "${STATUS_DIR}/history.log"
  chmod 0644 "${STATUS_DIR}/history.log"

  if [[ ! -f "$CONFIG_TARGET" ]]; then
    install_file "$CONFIG_SOURCE" "$CONFIG_TARGET" 0644
  else
    cp -p "$CONFIG_TARGET" "${CONFIG_TARGET}.backup-${BACKUP_SUFFIX}"
    echo "INFO: Existing config preserved at ${CONFIG_TARGET}; backup created."
  fi

  install_file "${PROJECT_ROOT}/scripts/noip-monitor.sh" "${BIN_DIR}/noip-monitor.sh" 0755
  install_file "${PROJECT_ROOT}/scripts/noip-update-hook.sh" "${BIN_DIR}/noip-update-hook.sh" 0755
  install_file "${PROJECT_ROOT}/scripts/noip-write-status.sh" "${BIN_DIR}/noip-write-status.sh" 0755
  install_file "${PROJECT_ROOT}/scripts/noip-check-consistency.sh" "${BIN_DIR}/noip-check-consistency.sh" 0755
  install_file "${PROJECT_ROOT}/api/noip-api.py" "${BIN_DIR}/noip-api.py" 0755

  install_file "${PROJECT_ROOT}/systemd/noip-monitor.service" "${SYSTEMD_DIR}/noip-monitor.service" 0644
  install_file "${PROJECT_ROOT}/systemd/noip-monitor.timer" "${SYSTEMD_DIR}/noip-monitor.timer" 0644
  install_file "${PROJECT_ROOT}/systemd/noip-api.service" "${SYSTEMD_DIR}/noip-api.service" 0644

  systemctl daemon-reload
  systemctl enable --now noip-monitor.timer
  systemctl enable --now noip-api.service

  echo "INFO: Installation complete."
  if [[ -f "$DUC_ENV_FILE" ]]; then
    echo "INFO: Existing No-IP DUC environment file found and left untouched: ${DUC_ENV_FILE}"
  else
    echo "INFO: No DUC environment file found at ${DUC_ENV_FILE}; this project does not create No-IP secrets."
  fi
  echo "INFO: Review ${CONFIG_TARGET} before enabling optional DUC restart."
  echo "INFO: Existing noip-duc.service was not modified."
}

main "$@"
