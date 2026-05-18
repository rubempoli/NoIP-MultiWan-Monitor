# noip-multiwan-monitor

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## Changelog

- 2026-05-17: Added DNS-based public IP detection fallback.
- 2026-05-17: Added known ISP names cache for ISP detection before WHOIS lookup.
- 2026-05-17: Made WHOIS ISP matching tolerant of accent and encoding differences.
- 2026-05-17: Added optional WHOIS-based ISP detection fallback.
- 2026-05-17: Renamed visible project references to multi-WAN.
- 2026-05-17: Initial GitHub-ready project structure, monitor, API, systemd units, installer, and documentation.

## Overview

`noip-multiwan-monitor` monitors the current public IP of a multi-WAN network and compares it with the IP currently published in DNS for a No-IP hostname. It is designed for a Debian host running No-IP DUC 3.x and a router where the active WAN can change during failover.

The first version focuses on reliable observation:

- checks the current public IP every minute through a systemd timer;
- resolves the No-IP hostname through DNS;
- writes a consolidated status file for Home Assistant and troubleshooting;
- appends relevant events to an audit-friendly history log;
- exposes plain text and JSON HTTP endpoints;
- prepares optional DUC restart behavior, disabled by default.
- reuses the installed No-IP DUC and its existing secrets file instead of managing credentials.

## Repository Layout

```text
config/    Example configuration
scripts/   Monitor, DUC hook, startup writer, and manual consistency check
api/       Lightweight Python HTTP API
systemd/   Service and timer units
docs/      Architecture, Home Assistant, and migration notes
install/   Conservative installer
```

## Runtime Files

Default runtime paths are configured in `/etc/noip-monitor.conf`:

```text
/var/lib/noip/status.txt
/var/lib/noip/history.log
```

The status file uses simple `KEY=value` lines:

```text
HOSTNAME=realswensson.ddns.net
CURRENT_PUBLIC_IP=187.59.12.49
PUBLISHED_DNS_IP=187.59.12.49
DNS_STATUS=OK
CURRENT_ISP=Claro
PREVIOUS_PUBLIC_IP=179.x.x.x
PREVIOUS_ISP=Vivo
LAST_CHECK=2026-05-17T20:15:00-03:00
LAST_IP_CHANGE=2026-05-17T20:13:42-03:00
LAST_DUC_HOOK_UPDATE=2026-05-17T20:13:50-03:00
LAST_DUC_RESTART_TRIGGER=
```

## API

Default API port: `8085`.

- `GET /noip` returns the status file as plain text.
- `GET /noip.json` returns the same status as JSON.
- `GET /history?lines=50` returns the last history lines.
- `GET /health` returns a simple health payload.

## Installation

On the Debian host:

```bash
sudo ./install/install.sh
sudo nano /etc/noip-monitor.conf
sudo systemctl status noip-monitor.timer
sudo systemctl status noip-api.service
```

The installer creates backups with `cp -p` before replacing existing installed files. It does not modify an existing `noip-duc.service`; use `systemd/noip-duc.service.example` as a reference.

The project does not install No-IP DUC and does not copy or rewrite its secrets. Keep the existing DUC environment file, usually:

```text
/etc/noip-duc.env
```

The example DUC unit keeps using that file through `EnvironmentFile=/etc/noip-duc.env`.

## DUC Restart

DUC restart is intentionally disabled by default:

```bash
ENABLE_DUC_RESTART="false"
```

After validating monitoring, history, DNS consistency, and API behavior, it can be enabled by setting:

```bash
ENABLE_DUC_RESTART="true"
DUC_SERVICE_NAME="noip-duc.service"
DUC_ENV_FILE="/etc/noip-duc.env"
DUC_BINARY="/usr/bin/noip-duc"
```

## Documentation

- [Architecture](docs/architecture.md)
- [Home Assistant](docs/home-assistant.md)
- [Migration from Existing Installation](docs/migration-from-existing-installation.md)
