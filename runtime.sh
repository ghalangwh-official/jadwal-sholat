#!/usr/bin/env bash

set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
JADWAL_FILE="${JADWAL_SHOLAT_JADWAL_FILE:-$SCRIPT_DIR/jadwal_sholat.json}"
SELECTED_ID_FILE="${JADWAL_SHOLAT_SELECTED_ID_FILE:-$SCRIPT_DIR/.selected_id.dat}"
LAST_PLAYED_FILE="${JADWAL_SHOLAT_LAST_PLAYED_FILE:-$SCRIPT_DIR/.runtime_last_played}"
PID_FILE="${JADWAL_SHOLAT_PID_FILE:-$SCRIPT_DIR/.runtime.pid}"
LOG_FILE="${JADWAL_SHOLAT_LOG_FILE:-$SCRIPT_DIR/runtime.log}"
ATHAN_ID_FILE="${JADWAL_SHOLAT_ATHAN_ID_FILE:-$SCRIPT_DIR/.athan_id}"
ATHAN_URL_FILE="${JADWAL_SHOLAT_ATHAN_URL_FILE:-$SCRIPT_DIR/.athan_url}"
ATHAN_SUBUH_ID_FILE="${JADWAL_SHOLAT_SUBUH_ATHAN_ID_FILE:-$SCRIPT_DIR/.athan_subuh_id}"
ATHAN_SUBUH_URL_FILE="${JADWAL_SHOLAT_SUBUH_ATHAN_URL_FILE:-$SCRIPT_DIR/.athan_subuh_url}"
ATHAN_ID="${JADWAL_SHOLAT_ATHAN_ID:-1a014366658c}"
ATHAN_URL="${JADWAL_SHOLAT_ATHAN_URL:-https://alfurqan.online/api/v1/athan/${ATHAN_ID}}"
SUBUH_ATHAN_ID="${JADWAL_SHOLAT_SUBUH_ATHAN_ID:-$ATHAN_ID}"
SUBUH_ATHAN_URL="${JADWAL_SHOLAT_SUBUH_ATHAN_URL:-$ATHAN_URL}"
SLEEP_INTERVAL="${JADWAL_SHOLAT_RUNTIME_INTERVAL:-20}"
DRY_RUN="${JADWAL_SHOLAT_DRY_RUN:-0}"
ONCE="${JADWAL_SHOLAT_ONCE:-0}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

ATHAN_URL_WAS_SET="${JADWAL_SHOLAT_ATHAN_URL+x}"

JADWAL_FILE="${JADWAL_SHOLAT_JADWAL_FILE:-$JADWAL_FILE}"
SELECTED_ID_FILE="${JADWAL_SHOLAT_SELECTED_ID_FILE:-$SELECTED_ID_FILE}"
LAST_PLAYED_FILE="${JADWAL_SHOLAT_LAST_PLAYED_FILE:-$LAST_PLAYED_FILE}"
PID_FILE="${JADWAL_SHOLAT_PID_FILE:-$PID_FILE}"
LOG_FILE="${JADWAL_SHOLAT_LOG_FILE:-$LOG_FILE}"
ATHAN_ID="${JADWAL_SHOLAT_ATHAN_ID:-$ATHAN_ID}"
ATHAN_URL="${JADWAL_SHOLAT_ATHAN_URL:-$ATHAN_URL}"
SUBUH_ATHAN_ID="${JADWAL_SHOLAT_SUBUH_ATHAN_ID:-$SUBUH_ATHAN_ID}"
SUBUH_ATHAN_URL="${JADWAL_SHOLAT_SUBUH_ATHAN_URL:-$SUBUH_ATHAN_URL}"
SLEEP_INTERVAL="${JADWAL_SHOLAT_RUNTIME_INTERVAL:-$SLEEP_INTERVAL}"
JADWAL_SHOLAT_JADWAL_URL="${JADWAL_SHOLAT_JADWAL_URL:-https://api.myquran.com/v2/sholat/jadwal}"

if [ -s "$ATHAN_ID_FILE" ]; then
    ATHAN_ID="$(tr -d '\r\n' < "$ATHAN_ID_FILE")"
fi
if [ -s "$ATHAN_URL_FILE" ]; then
    ATHAN_URL="$(tr -d '\r\n' < "$ATHAN_URL_FILE")"
else
    if [ -z "${ATHAN_URL_WAS_SET:-}" ]; then
        ATHAN_URL="https://alfurqan.online/api/v1/athan/${ATHAN_ID}"
    fi
fi
if [ -s "$ATHAN_SUBUH_ID_FILE" ]; then
    SUBUH_ATHAN_ID="$(tr -d '\r\n' < "$ATHAN_SUBUH_ID_FILE")"
fi
if [ -s "$ATHAN_SUBUH_URL_FILE" ]; then
    SUBUH_ATHAN_URL="$(tr -d '\r\n' < "$ATHAN_SUBUH_URL_FILE")"
fi

required_commands=("jq" "curl")
if [ "$DRY_RUN" != "1" ]; then
    required_commands+=("mpv")
fi

function log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

function die() {
    log "[!] $1"
    exit 1
}

function ensure_commands() {
    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || die "Command '$cmd' tidak ditemukan"
    done
}

function fetch_json() {
    local url="$1"
    local output_file="$2"
    local tmp_file
    tmp_file="$(mktemp "${output_file}.XXXXXX")" || return 1

    if ! curl -fsSL "$url" | jq '.' >"$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$output_file"
}

function is_numeric_id() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

function schedule_file_is_valid() {
    jq -e '
        .status == true and
        (.data | type == "object") and
        (.data.id | type == "number") and
        (.data.jadwal | type == "object")
    ' "$JADWAL_FILE" >/dev/null 2>&1
}

function prayer_audio_url() {
    local prayer="$1"
    case "$prayer" in
        subuh)
            printf '%s\n' "${SUBUH_ATHAN_URL:-$ATHAN_URL}"
            ;;
        *)
            printf '%s\n' "${ATHAN_URL:-}"
            ;;
    esac
}

function current_time_hm() {
    if [ -n "${JADWAL_SHOLAT_TEST_NOW:-}" ]; then
        printf '%s' "${JADWAL_SHOLAT_TEST_NOW}"
    else
        date +%H:%M
    fi
}

function current_date_ymd() {
    if [ -n "${JADWAL_SHOLAT_TEST_DATE:-}" ]; then
        printf '%s' "${JADWAL_SHOLAT_TEST_DATE}"
    else
        date +%F
    fi
}

function selected_city_id() {
    if [ -s "$SELECTED_ID_FILE" ]; then
        local selected_id
        selected_id="$(tr -d '\r\n' < "$SELECTED_ID_FILE")"
        if is_numeric_id "$selected_id"; then
            printf '%s\n' "$selected_id"
            return 0
        fi
    fi

    if [ -f "$JADWAL_FILE" ] && schedule_file_is_valid; then
        jq -r '.data.id // empty' "$JADWAL_FILE"
        return 0
    fi

    return 1
}

function ensure_schedule() {
    local today schedule_date city_id
    today="$(current_date_ymd)"
    city_id="$(selected_city_id)" || return 1

    schedule_date=""
    if [ -f "$JADWAL_FILE" ]; then
        schedule_date="$(jq -r '.request.path | split("/")[-1] // empty' "$JADWAL_FILE" 2>/dev/null | cut -d- -f1-3)"
    fi

    if [ ! -f "$JADWAL_FILE" ] || [ -z "$schedule_date" ] || [ "$schedule_date" != "$today" ]; then
        log "refresh jadwal untuk kota ${city_id} (${today})"
        fetch_json "${JADWAL_SHOLAT_JADWAL_URL}/${city_id}/${today}" "$JADWAL_FILE" || die "Gagal mengambil jadwal sholat"
        schedule_date="$(jq -r '.request.path | split("/")[-1] // empty' "$JADWAL_FILE" 2>/dev/null | cut -d- -f1-3)"
        if ! schedule_file_is_valid; then
            die "Jadwal API tidak valid untuk ID ${city_id}"
        fi
    fi
}

function pray_time_for() {
    local prayer="$1"
    jq -r ".data.jadwal.${prayer} // empty" "$JADWAL_FILE"
}

function prayer_label() {
    case "$1" in
        subuh) echo "Subuh" ;;
        dzuhur) echo "Dzuhur" ;;
        ashar) echo "Ashar" ;;
        maghrib) echo "Maghrib" ;;
        isya) echo "Isya" ;;
        *) echo "$1" ;;
    esac
}

function mark_played() {
    local key="$1"
    grep -Fxq "$key" "$LAST_PLAYED_FILE" 2>/dev/null && return 1
    printf '%s\n' "$key" >> "$LAST_PLAYED_FILE"
    return 0
}

function play_athan() {
    local prayer="$1"
    local prayer_time="$2"
    local athan_url
    local key
    key="$(current_date_ymd)|${prayer}|${prayer_time}"
    athan_url="$(prayer_audio_url "$prayer")"

    if ! mark_played "$key"; then
        return 1
    fi

    log "adzan ${prayer} (${prayer_time})"

    if command -v termux-notification >/dev/null 2>&1; then
        termux-notification -t "Jadwal Sholat" -c "Masuk waktu $(prayer_label "$prayer")" >/dev/null 2>&1 || true
    fi

    if [ "$DRY_RUN" = "1" ]; then
        log "dry-run aktif, audio tidak diputar"
        return 0
    fi

    if mpv --no-video --really-quiet --force-window=no "$athan_url" >/dev/null 2>&1; then
        return 0
    fi

    local tmp_audio
    tmp_audio="$(mktemp "$SCRIPT_DIR/.athan.XXXXXX.mp3")" || return 1
    if curl -fsSL "$athan_url" -o "$tmp_audio" && mpv --no-video --really-quiet --force-window=no "$tmp_audio" >/dev/null 2>&1; then
        rm -f "$tmp_audio"
        return 0
    fi

    rm -f "$tmp_audio"
    log "gagal memutar adzan"
    return 1
}

function run_loop() {
    touch "$LOG_FILE" "$LAST_PLAYED_FILE"

    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock >/dev/null 2>&1 || true
    fi

    trap 'if command -v termux-wake-unlock >/dev/null 2>&1; then termux-wake-unlock >/dev/null 2>&1 || true; fi' EXIT

    while true; do
        ensure_schedule || die "jadwal sholat tidak tersedia"

        for prayer in subuh dzuhur ashar maghrib isya; do
            prayer_time="$(pray_time_for "$prayer")"
            now_time="$(current_time_hm)"
            if [ -n "$prayer_time" ] && [ "$now_time" = "$prayer_time" ]; then
                play_athan "$prayer" "$prayer_time" || true
            fi
        done

        if [ "$ONCE" = "1" ]; then
            exit 0
        fi

        sleep "$SLEEP_INTERVAL"
    done
}

function start_background() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
        log "runtime sudah berjalan dengan pid $(cat "$PID_FILE")"
        exit 0
    fi

    nohup bash "$SCRIPT_DIR/runtime.sh" run >>"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    log "runtime background dimulai: pid $(cat "$PID_FILE")"
}

function stop_background() {
    if [ ! -f "$PID_FILE" ]; then
        log "runtime background tidak aktif"
        exit 0
    fi

    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1 || true
        log "runtime background dihentikan: pid $pid"
    else
        log "runtime background sudah mati: pid $pid"
    fi

    rm -f "$PID_FILE"
}

function status_background() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
        log "runtime aktif: pid $(cat "$PID_FILE")"
    else
        log "runtime tidak aktif"
    fi
}

ensure_commands

case "${1:-run}" in
    run)
        run_loop
        ;;
    start)
        run_loop
        ;;
    bg)
        start_background
        ;;
    stop)
        stop_background
        ;;
    status)
        status_background
        ;;
    *)
        echo "usage: $0 {run|start|bg|stop|status}"
        exit 1
        ;;
esac
