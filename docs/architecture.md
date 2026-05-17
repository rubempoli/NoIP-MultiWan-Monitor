# Architecture

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## Changelog

- 2026-05-17: Initial architecture document.

## Design

The monitor separates two facts that are often mixed together:

- `CURRENT_PUBLIC_IP`: the public IP observed from the current outbound route.
- `PUBLISHED_DNS_IP`: the IP returned by DNS for the configured No-IP hostname.

`DNS_STATUS` is derived from those values:

- `OK`: both IPs match.
- `DIVERGENT`: both IPs are known but different.
- `UNKNOWN`: one side could not be determined.

## Components

`scripts/noip-monitor.sh` runs through `noip-monitor.timer`. It reads `/etc/noip-monitor.conf`, detects the current public IP, resolves DNS, detects the ISP from configured prefixes, writes the status file atomically, and appends significant events to history.

`api/noip-api.py` is a dependency-light HTTP API for Home Assistant and troubleshooting. It does not perform checks itself; it only reads monitor output.

`scripts/noip-update-hook.sh` preserves the existing No-IP DUC integration. When DUC reports a change, the hook records the update in the same status and history files.

`scripts/noip-write-status.sh` exists for `ExecStartPost` compatibility and delegates to the monitor.

## No-IP DUC Boundary

This project intentionally reuses the installed No-IP DUC instead of replacing it. The DUC binary, service, and secrets remain external responsibilities:

```bash
DUC_BINARY="/usr/bin/noip-duc"
DUC_ENV_FILE="/etc/noip-duc.env"
DUC_SERVICE_NAME="noip-duc.service"
```

The monitor reads public network state and DNS state. It does not need No-IP credentials. The DUC hook receives `CURRENT_IP` and `LAST_IP` from the DUC process and records them, but it does not read or write secrets.

## ISP Detection

ISP detection uses conservative configured IPv4 prefixes:

```bash
ISP_PREFIX_RULES="Claro=187.59.;Vivo=179."
```

This is intentionally local and cheap. If the observed prefixes are not stable enough, leave the rule empty and collect history before enabling labels.

## Optional DUC Restart

The monitor has an optional restart path:

```bash
ENABLE_DUC_RESTART="false"
DUC_SERVICE_NAME="noip-duc.service"
```

It is disabled by default because the first milestone is to validate observation and consistency before changing DUC behavior.
