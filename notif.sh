#!/usr/bin/env bash

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
JADWAL_FILE="${JADWAL_SHOLAT_JADWAL_FILE:-$SCRIPT_DIR/jadwal_sholat.json}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

JADWAL_FILE="${JADWAL_SHOLAT_JADWAL_FILE:-$JADWAL_FILE}"

if ! command -v termux-notification >/dev/null 2>&1; then
    echo "termux-notification tidak tersedia"
    exit 1
fi

if [ ! -f "$JADWAL_FILE" ]; then
    echo "jadwal_sholat.json belum ada"
    exit 1
fi

if ! jq -e '
  .status == true and
  (.data | type == "object") and
  (.data.jadwal | type == "object")
' "$JADWAL_FILE" >/dev/null 2>&1; then
    echo "jadwal_sholat.json tidak valid"
    exit 1
fi

termux-notification -t "Jadwal Sholat" -c "$(cat <<EOF
Subuh    : $(jq -r '.data.jadwal.subuh // empty' "$JADWAL_FILE")
Imsak    : $(jq -r '.data.jadwal.imsak // empty' "$JADWAL_FILE")
Dzuhur   : $(jq -r '.data.jadwal.dzuhur // empty' "$JADWAL_FILE")
Ashar    : $(jq -r '.data.jadwal.ashar // empty' "$JADWAL_FILE")
Maghrib  : $(jq -r '.data.jadwal.maghrib // empty' "$JADWAL_FILE")
Isya     : $(jq -r '.data.jadwal.isya // empty' "$JADWAL_FILE")
EOF
)"
