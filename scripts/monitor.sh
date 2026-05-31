#!/usr/bin/env bash

set -euo pipefail

PROCESS_NAME="agent_app.py"
APP_PORT="15034"

LOG_DIR="/var/log/agent-app"
LOG_FILE="${LOG_DIR}/monitor.log"

MAX_LOG_SIZE=$((10 * 1024 * 1024))
MAX_LOG_COUNT=10

CPU_THRESHOLD="20"
MEM_THRESHOLD="10"
DISK_THRESHOLD="80"

print_line() {
    echo "=================================================="
}

get_process_pid() {
    pgrep -f "$PROCESS_NAME" | head -n 1 || true
}

check_process() {
    local pid
    pid="$(get_process_pid)"

    if [ -z "$pid" ]; then
        echo "Checking process '${PROCESS_NAME}'... [FAIL]"
        exit 1
    fi

    echo "Checking process '${PROCESS_NAME}'... [OK] (PID: ${pid})"
    PROCESS_PID="$pid"
}

check_port() {
    if ss -tuln | awk -v port=":${APP_PORT}" '$1 == "tcp" && $2 == "LISTEN" && index($5, port) > 0 { found = 1 } END { exit found ? 0 : 1 }'; then
        echo "Checking port ${APP_PORT}... [OK]"
    else
        echo "Checking port ${APP_PORT}... [FAIL]"
        exit 1
    fi
}

check_firewall() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo "[WARNING] UFW command not found"
        return 0
    fi

    if [ -r /etc/ufw/ufw.conf ] && grep -q '^ENABLED=yes' /etc/ufw/ufw.conf; then
        echo "Checking UFW firewall... [OK]"
    elif ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "Checking UFW firewall... [OK]"
    else
        echo "[WARNING] UFW firewall is inactive"
    fi
}

get_cpu_usage() {
    local cpu user nice system idle iowait irq softirq steal
    local idle1 total1 idle2 total2 idle_delta total_delta

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    idle1=$((idle + iowait))
    total1=$((user + nice + system + idle + iowait + irq + softirq + steal))

    sleep 0.5

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    idle2=$((idle + iowait))
    total2=$((user + nice + system + idle + iowait + irq + softirq + steal))

    idle_delta=$((idle2 - idle1))
    total_delta=$((total2 - total1))

    awk -v idle="$idle_delta" -v total="$total_delta" 'BEGIN {
        if (total == 0) {
            printf "0.0"
        } else {
            printf "%.1f", (1 - idle / total) * 100
        }
    }'
}

get_mem_usage() {
    free | awk '/Mem:/ {
        printf "%.1f", ($3 / $2) * 100
    }'
}

get_disk_usage() {
    df / | awk 'NR == 2 {
        gsub("%", "", $5)
        print $5
    }'
}

is_greater_than() {
    awk -v value="$1" -v threshold="$2" 'BEGIN {
        exit !(value > threshold)
    }'
}

rotate_log_if_needed() {
    if [ ! -d "$LOG_DIR" ]; then
        echo "Log directory not found: ${LOG_DIR}"
        exit 1
    fi

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    local log_size
    log_size="$(stat -c%s "$LOG_FILE")"

    if [ "$log_size" -lt "$MAX_LOG_SIZE" ]; then
        return 0
    fi

    rm -f "${LOG_FILE}.${MAX_LOG_COUNT}"

    local i
    for ((i=MAX_LOG_COUNT-1; i>=1; i--)); do
        if [ -f "${LOG_FILE}.${i}" ]; then
            mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
        fi
    done

    mv "$LOG_FILE" "${LOG_FILE}.1"
    touch "$LOG_FILE"
}

main() {
    PROCESS_PID=""

    print_line
    echo "SYSTEM MONITOR RESULT"
    print_line

    echo
    echo "[HEALTH CHECK]"
    check_process
    check_port

    echo
    echo "[FIREWALL CHECK]"
    check_firewall

    echo
    echo "[RESOURCE MONITORING]"

    local cpu_usage
    local mem_usage
    local disk_usage
    local timestamp

    cpu_usage="$(get_cpu_usage)"
    mem_usage="$(get_mem_usage)"
    disk_usage="$(get_disk_usage)"
    timestamp="$(date "+%Y-%m-%d %H:%M:%S")"

    echo "CPU Usage  : ${cpu_usage}%"
    echo "MEM Usage  : ${mem_usage}%"
    echo "DISK Used  : ${disk_usage}%"

    echo

    if is_greater_than "$cpu_usage" "$CPU_THRESHOLD"; then
        echo "[WARNING] CPU threshold exceeded (${cpu_usage}% > ${CPU_THRESHOLD}%)"
    fi

    if is_greater_than "$mem_usage" "$MEM_THRESHOLD"; then
        echo "[WARNING] MEM threshold exceeded (${mem_usage}% > ${MEM_THRESHOLD}%)"
    fi

    if is_greater_than "$disk_usage" "$DISK_THRESHOLD"; then
        echo "[WARNING] DISK threshold exceeded (${disk_usage}% > ${DISK_THRESHOLD}%)"
    fi

    rotate_log_if_needed

    echo "[${timestamp}] PID:${PROCESS_PID} CPU:${cpu_usage}% MEM:${mem_usage}% DISK_USED:${disk_usage}%" >> "$LOG_FILE"

    echo
    echo "[INFO] Log appended: ${LOG_FILE}"
}

main
