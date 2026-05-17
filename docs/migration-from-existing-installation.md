# Migration From Existing Installation

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## Changelog

- 2026-05-17: Initial migration plan from the existing AppHost setup.

## Existing Pieces Reused

The project keeps the current ideas that already work:

- No-IP DUC remains installed and managed outside this project.
- The existing No-IP DUC secrets file remains in place and is reused by the DUC service.
- `noip-update-hook.sh` remains the DUC `--exec-on-change` hook.
- `noip-write-status.sh` remains usable from `ExecStartPost`.
- `GET /noip` remains a plain text troubleshooting endpoint.
- DNS consistency still uses simple DNS resolution for the hostname.

## Migration Plan

1. Copy or clone this project to AppHost.
2. Run the installer:

   ```bash
   sudo ./install/install.sh
   ```

3. Review `/etc/noip-monitor.conf` and adjust:

   ```bash
   NOIP_HOSTNAME="realswensson.ddns.net"
   ISP_PREFIX_RULES="Claro=187.59.;Vivo=179."
   ENABLE_DUC_RESTART="false"
   DUC_ENV_FILE="/etc/noip-duc.env"
   DUC_BINARY="/usr/bin/noip-duc"
   ```

4. Check the first monitor run:

   ```bash
   sudo systemctl start noip-monitor.service
   cat /var/lib/noip/status.txt
   tail -n 50 /var/lib/noip/history.log
   ```

5. Validate the API:

   ```bash
   curl http://127.0.0.1:8085/noip
   curl http://127.0.0.1:8085/noip.json
   ```

6. Integrate DUC after the monitor is validated. Keep the existing secrets file in place, usually `/etc/noip-duc.env`. Compare the current unit with `systemd/noip-duc.service.example` and add only the hook/status lines needed:

   ```ini
   EnvironmentFile=/etc/noip-duc.env
   Environment=NOIP_MONITOR_CONFIG=/etc/noip-monitor.conf
   ExecStart=/usr/bin/noip-duc --exec-on-change "/usr/local/bin/noip-update-hook.sh"
   ExecStartPost=/usr/local/bin/noip-write-status.sh
   ```

   Do not copy No-IP credentials into this repository.

7. Keep `ENABLE_DUC_RESTART=false` until DNS consistency and history behavior are trusted during real failover.

## Rollback Notes

The installer creates backups before replacing installed files. Existing `/etc/noip-monitor.conf` is preserved and backed up rather than overwritten.
