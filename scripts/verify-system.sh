#!/usr/bin/env bash

set -u

readonly EXPECTED_SSH_PORT="${DO1_SSH_PORT:-2022}"

section() {
    printf '\n== %s ==\n' "$1"
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'WARN: required command not found: %s\n' "$1" >&2
        return 1
    fi
}

section "Operating system"
if [[ -r /etc/os-release ]]; then
    grep -E '^(NAME|VERSION)=' /etc/os-release
else
    printf 'WARN: /etc/os-release is unavailable\n' >&2
fi
printf 'Hostname: %s\n' "$(hostnamectl --static 2>/dev/null || hostname)"

section "Time synchronization"
if check_command timedatectl; then
    timedatectl show --property=Timezone --property=NTP --property=NTPSynchronized
fi

section "Network"
if check_command ip; then
    ip -brief address
    printf '\nDefault route:\n'
    ip route show default
fi
if check_command getent; then
    if getent ahosts ya.ru >/dev/null; then
        printf 'PASS: DNS resolution works\n'
    else
        printf 'WARN: DNS resolution failed\n' >&2
    fi
fi

section "SSH service"
ssh_service=""
for candidate in ssh sshd; do
    if systemctl cat "$candidate" >/dev/null 2>&1; then
        ssh_service="$candidate"
        break
    fi
done

if [[ -n "$ssh_service" ]]; then
    printf 'Service: %s\n' "$ssh_service"
    systemctl is-enabled "$ssh_service" 2>/dev/null || true
    systemctl is-active "$ssh_service" 2>/dev/null || true
else
    printf 'WARN: SSH service was not found\n' >&2
fi

if command -v sshd >/dev/null 2>&1; then
    configured_port="$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2; exit}')"
    printf 'Configured port: %s\n' "${configured_port:-unknown}"
    if [[ "$configured_port" == "$EXPECTED_SSH_PORT" ]]; then
        printf 'PASS: SSH port matches expected value %s\n' "$EXPECTED_SSH_PORT"
    else
        printf 'WARN: expected SSH port %s\n' "$EXPECTED_SSH_PORT" >&2
    fi
fi

section "Root filesystem"
df -Th /

section "User cron jobs"
if check_command crontab; then
    crontab -l 2>/dev/null || printf 'No user crontab configured\n'
fi
