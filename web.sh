#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
HOST="${JADWAL_SHOLAT_WEB_HOST:-127.0.0.1}"
PORT="${JADWAL_SHOLAT_WEB_PORT:-8787}"
PID_FILE="${JADWAL_SHOLAT_WEB_PID_FILE:-$ROOT_DIR/.web.pid}"
LOG_FILE="${JADWAL_SHOLAT_WEB_LOG_FILE:-$ROOT_DIR/web.log}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

HOST="${JADWAL_SHOLAT_WEB_HOST:-$HOST}"
PORT="${JADWAL_SHOLAT_WEB_PORT:-$PORT}"

function die() {
    echo " [!] $1"
    exit 1
}

function pick_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s\n' python3
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        printf '%s\n' python
        return 0
    fi
    return 1
}

PYTHON_BIN="$(pick_python)" || die "python3/python tidak ditemukan. Install python di Termux dulu."

function run_server() {
    exec "$PYTHON_BIN" -m http.server "$PORT" --bind "$HOST" --directory "$ROOT_DIR"
}

function start_bg() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
        echo " [i] web server sudah berjalan: pid $(cat "$PID_FILE")"
        exit 0
    fi

    nohup bash "$ROOT_DIR/web.sh" run >>"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo " [i] web server background dimulai: pid $(cat "$PID_FILE")"
}

function stop_bg() {
    if [ ! -f "$PID_FILE" ]; then
        echo " [i] web server background tidak aktif"
        exit 0
    fi

    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1 || true
        echo " [i] web server dihentikan: pid $pid"
    else
        echo " [i] web server sudah mati: pid $pid"
    fi
    rm -f "$PID_FILE"
}

function status_bg() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
        echo " [i] web server aktif: pid $(cat "$PID_FILE")"
    else
        echo " [i] web server tidak aktif"
    fi
}

function open_browser() {
    local open_host="$HOST"
    case "$open_host" in
        0.0.0.0|::)
            open_host="127.0.0.1"
            ;;
    esac
    local url="http://${open_host}:${PORT}/web/"
    if [ ! -f "$PID_FILE" ] || ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
        start_bg
        sleep 1
    fi

    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$url" >/dev/null 2>&1 || true
    fi

    echo " [i] buka: $url"
}

case "${1:-open}" in
    run)
        echo " [i] serving http://${HOST}:${PORT}/"
        run_server
        ;;
    start|bg)
        start_bg
        ;;
    stop)
        stop_bg
        ;;
    status)
        status_bg
        ;;
    open)
        open_browser
        ;;
    *)
        echo "usage: $0 {run|start|bg|stop|status|open}"
        exit 1
        ;;
esac
