#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FIXTURE="$ROOT_DIR/tests/fixtures/jadwal.sample.json"
TMP_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
WORK_DIR="$(mktemp -d "$TMP_DIR/jadwal-sholat-smoke.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

echo "[1/3] syntax check"
bash -n "$ROOT_DIR/jadwal-sholat.sh"
bash -n "$ROOT_DIR/runtime.sh"
bash -n "$ROOT_DIR/notif.sh"

echo "[2/3] runtime dry-run against fixture"
cp "$FIXTURE" "$WORK_DIR/jadwal_sholat.json"
printf '%s\n' '1505' > "$WORK_DIR/.selected_id.dat"

JADWAL_SHOLAT_JADWAL_FILE="$WORK_DIR/jadwal_sholat.json" \
JADWAL_SHOLAT_SELECTED_ID_FILE="$WORK_DIR/.selected_id.dat" \
JADWAL_SHOLAT_LAST_PLAYED_FILE="$WORK_DIR/.runtime_last_played" \
JADWAL_SHOLAT_LOG_FILE="$WORK_DIR/runtime.log" \
JADWAL_SHOLAT_DRY_RUN=1 \
JADWAL_SHOLAT_ONCE=1 \
JADWAL_SHOLAT_TEST_DATE=2025-03-22 \
JADWAL_SHOLAT_TEST_NOW=04:28 \
bash "$ROOT_DIR/runtime.sh" run

grep -q "adzan subuh (04:28)" "$WORK_DIR/runtime.log"

echo "[3/3] config example present"
[ -f "$ROOT_DIR/config.example.sh" ]

echo "smoke ok"
