# Architecture

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## Changelog

- 2026-05-17: Persisted status before optional DUC restart to avoid reentrant duplicate IP change events.
- 2026-05-17: Added DNS-based public IP detection fallback.
- 2026-05-17: Added known ISP names cache for ISP detection before WHOIS lookup.
- 2026-05-17: Documented accent and encoding tolerance for WHOIS ISP matching.
- 2026-05-17: Added optional WHOIS-based ISP detection fallback.
- 2026-05-17: Initial architecture document.

## Design

The monitor separates two facts that are often mixed together:

- `CURRENT_PUBLIC_IP`: the public IP observed from the current outbound route.
- `PUBLISHED_DNS_IP`: the IP returned by DNS for the configured No-IP hostname.

`CURRENT_PUBLIC_IP` is detected through configured HTTP endpoints first, then through DNS-based fallback queries such as:

```bash
PUBLIC_IP_DNS_QUERIES="myip.opendns.com@208.67.222.222"
```

This keeps failover detection working even when local DNS is unhealthy or slow during a WAN transition.

`DNS_STATUS` is derived from those values:

- `OK`: both IPs match.
- `DIVERGENT`: both IPs are known but different.
- `UNKNOWN`: one side could not be determined.

## Components

`scripts/noip-monitor.sh` runs through `noip-monitor.timer`. It reads `/etc/noip-monitor.conf`, detects the current public IP, resolves DNS, detects the ISP from configured rules, writes the status file atomically, and appends significant events to history.

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

ISP detection uses configured methods in order:

```bash
ISP_DETECTION_METHODS="known_isp_names,whois"
KNOWN_ISP_NAMES_FILE="/var/lib/noip/known-isp-names.conf"
WHOIS_ISP_RULES="Vivo=TELEFONICA,TELEF,GVT,AS18881;Claro=CLARO,NET SERVICOS,EMBRATEL,AS28573"
```

Known ISP names are tried first because they are local, cheap, and auditable. The file uses simple `IP=ISP` lines:

```text
187.59.12.49=Vivo
```

When an IP is not found locally, WHOIS is used as a fallback. If WHOIS maps the IP to a configured provider label, the monitor appends the learned mapping to `KNOWN_ISP_NAMES_FILE` and records a `KNOWN_ISP_NAME_LEARNED` history event.

Prefix matching remains available as an optional method if you want coarse rules before WHOIS:

```bash
ISP_DETECTION_METHODS="known_isp_names,prefix,whois"
ISP_PREFIX_RULES="Vivo=187.59.,179.;Claro="
```

WHOIS matching normalizes text toward ASCII with `iconv` when available. Tokens should still stay broad and ASCII-only to survive encoding differences. For example, `TELEF` matches both `TELEFONICA` and accent-damaged variants returned by some terminals.

The monitor never writes raw WHOIS output to status or history. It only writes the configured provider label, such as `Vivo` or `Claro`.

## Optional DUC Restart

The monitor has an optional restart path:

```bash
ENABLE_DUC_RESTART="false"
DUC_SERVICE_NAME="noip-duc.service"
```

It is disabled by default because the first milestone is to validate observation and consistency before changing DUC behavior.
