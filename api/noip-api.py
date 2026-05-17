#!/usr/bin/env python3
"""Lightweight No-IP monitor API.

Author: Rubem Swensson
Co-Authors: ChatGPT + Codex
Changelog:
- 2026-05-17: Added plain text, JSON, health, and history endpoints.
"""

from __future__ import annotations

import json
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


CONFIG_FILE = os.environ.get("NOIP_MONITOR_CONFIG", "/etc/noip-monitor.conf")


def parse_shell_config(config_path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    path = Path(config_path)
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        values[key] = value
    return resolve_config_references(values)


def resolve_config_references(values: dict[str, str]) -> dict[str, str]:
    variable_pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
    resolved = dict(values)

    for _ in range(5):
        changed = False
        for key, value in list(resolved.items()):
            def replace_variable(match: re.Match[str]) -> str:
                variable_name = match.group(1)
                return resolved.get(variable_name, os.environ.get(variable_name, match.group(0)))

            new_value = variable_pattern.sub(replace_variable, value)
            new_value = os.path.expandvars(new_value)
            if new_value != value:
                resolved[key] = new_value
                changed = True
        if not changed:
            break
    return resolved


CONFIG = parse_shell_config(CONFIG_FILE)
STATUS_FILE = Path(os.environ.get("STATUS_FILE", CONFIG.get("STATUS_FILE", "/var/lib/noip/status.txt")))
HISTORY_FILE = Path(os.environ.get("HISTORY_FILE", CONFIG.get("HISTORY_FILE", "/var/lib/noip/history.log")))
API_BIND_HOST = os.environ.get("API_BIND_HOST", CONFIG.get("API_BIND_HOST", "0.0.0.0"))
API_PORT = int(os.environ.get("API_PORT", CONFIG.get("API_PORT", "8085")))
API_HISTORY_DEFAULT_LINES = int(os.environ.get("API_HISTORY_DEFAULT_LINES", CONFIG.get("API_HISTORY_DEFAULT_LINES", "50")))
API_HISTORY_MAX_LINES = int(os.environ.get("API_HISTORY_MAX_LINES", CONFIG.get("API_HISTORY_MAX_LINES", "500")))


def parse_status(text: str) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw_line in text.splitlines():
        if not raw_line or "=" not in raw_line:
            continue
        key, value = raw_line.split("=", 1)
        data[key] = value
    return data


def read_tail(path: Path, lines: int) -> list[str]:
    if not path.exists():
        return []
    content = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return content[-lines:]


class NoIpHandler(BaseHTTPRequestHandler):
    server_version = "NoIpMultiWanMonitor/0.1.0"

    def log_message(self, format: str, *args: object) -> None:
        return

    def send_text(self, status_code: int, body: str, content_type: str = "text/plain; charset=utf-8") -> None:
        encoded_body = body.encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded_body)))
        self.end_headers()
        self.wfile.write(encoded_body)

    def send_json(self, status_code: int, payload: object) -> None:
        body = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        self.send_text(status_code, body, "application/json; charset=utf-8")

    def do_GET(self) -> None:
        parsed_url = urlparse(self.path)

        if parsed_url.path == "/health":
            self.send_json(200, {"status": "ok"})
            return

        if parsed_url.path == "/noip":
            try:
                self.send_text(200, STATUS_FILE.read_text(encoding="utf-8"))
            except OSError as error:
                self.send_text(500, f"ERROR: Could not read status file: {error}\n")
            return

        if parsed_url.path == "/noip.json":
            try:
                status_text = STATUS_FILE.read_text(encoding="utf-8")
            except OSError as error:
                self.send_json(500, {"error": f"Could not read status file: {error}"})
                return
            self.send_json(200, parse_status(status_text))
            return

        if parsed_url.path == "/history":
            query = parse_qs(parsed_url.query)
            requested_lines = query.get("lines", [str(API_HISTORY_DEFAULT_LINES)])[0]
            try:
                line_count = min(max(int(requested_lines), 1), API_HISTORY_MAX_LINES)
            except ValueError:
                line_count = API_HISTORY_DEFAULT_LINES
            self.send_text(200, "\n".join(read_tail(HISTORY_FILE, line_count)) + "\n")
            return

        self.send_text(404, "Not found\n")


def main() -> None:
    HTTPServer((API_BIND_HOST, API_PORT), NoIpHandler).serve_forever()


if __name__ == "__main__":
    main()
