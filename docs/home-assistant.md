# Home Assistant

Author: Rubem Swensson  
Co-Authors: ChatGPT + Codex

## Changelog

- 2026-05-17: Initial REST sensor example.

## REST Sensor Example

Use `/noip.json` as the primary integration endpoint:

```yaml
rest:
  - resource: "http://APPHOST_IP:8085/noip.json"
    scan_interval: 60
    sensor:
      - name: "No-IP Public IP"
        value_template: "{{ value_json.CURRENT_PUBLIC_IP }}"
      - name: "No-IP Published DNS IP"
        value_template: "{{ value_json.PUBLISHED_DNS_IP }}"
      - name: "No-IP DNS Status"
        value_template: "{{ value_json.DNS_STATUS }}"
      - name: "No-IP Current ISP"
        value_template: "{{ value_json.CURRENT_ISP }}"
      - name: "No-IP Previous Public IP"
        value_template: "{{ value_json.PREVIOUS_PUBLIC_IP }}"
      - name: "No-IP Last Check"
        value_template: "{{ value_json.LAST_CHECK }}"
      - name: "No-IP Last IP Change"
        value_template: "{{ value_json.LAST_IP_CHANGE }}"
```

Replace `APPHOST_IP` with the Debian host IP address.

## Troubleshooting

Plain text status remains available at:

```text
http://APPHOST_IP:8085/noip
```

Recent history is available at:

```text
http://APPHOST_IP:8085/history?lines=50
```
