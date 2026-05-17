#!/usr/bin/env bash
# Initial status writer for service startup
# Author: Rubem Swensson
# Co-Authors: ChatGPT + Codex
# Changelog:
# - 2026-05-17: Refactored startup writer to delegate consolidated status generation to the monitor.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${NOIP_MONITOR_SCRIPT:-${SCRIPT_DIR}/noip-monitor.sh}"

if [[ ! -x "$MONITOR_SCRIPT" ]]; then
  echo "ERROR: Monitor script is not executable: $MONITOR_SCRIPT" >&2
  exit 1
fi

"$MONITOR_SCRIPT"
