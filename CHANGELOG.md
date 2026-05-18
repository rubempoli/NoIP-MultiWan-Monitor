# Changelog

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## 0.1.0 - 2026-05-17

- Added DNS-based public IP detection fallback.
- Added known ISP names cache for ISP detection before WHOIS lookup.
- Made WHOIS ISP matching tolerant of accent and encoding differences.
- Added optional WHOIS-based ISP detection fallback.
- Updated installer to restart the API service after installing new code.
- Renamed visible project references to multi-WAN.
- Created initial GitHub-ready project structure.
- Added configurable periodic monitor.
- Added consolidated status file with public IP, DNS IP, DNS status, ISP, and timestamps.
- Added append-only history log.
- Added lightweight API with `/noip`, `/noip.json`, `/history`, and `/health`.
- Added systemd service and timer units.
- Added conservative installer with backups.
- Added migration and Home Assistant documentation.
- Prepared optional DUC restart integration, disabled by default.
