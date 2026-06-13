#!/usr/bin/env bash

# Copy this file to config.sh and edit the values you want to override.
# The main scripts source config.sh automatically when it exists.

JADWAL_SHOLAT_KOTA_URL="${JADWAL_SHOLAT_KOTA_URL:-https://api.myquran.com/v3/sholat/kabkota/semua}"
JADWAL_SHOLAT_CITY_SEARCH_URL="${JADWAL_SHOLAT_CITY_SEARCH_URL:-https://api.myquran.com/v3/sholat/kabkota/cari}"
JADWAL_SHOLAT_JADWAL_URL="${JADWAL_SHOLAT_JADWAL_URL:-https://api.myquran.com/v2/sholat/jadwal}"
JADWAL_SHOLAT_QURAN_SEARCH_URL="${JADWAL_SHOLAT_QURAN_SEARCH_URL:-https://api.myquran.com/v3/quran/search}"
JADWAL_SHOLAT_QURAN_RANDOM_URL="${JADWAL_SHOLAT_QURAN_RANDOM_URL:-https://api.myquran.com/v3/quran/random}"
JADWAL_SHOLAT_TAFSEER_URL="${JADWAL_SHOLAT_TAFSEER_URL:-https://alfurqan.online/api/v1/tafseer}"
JADWAL_SHOLAT_ATHAN_LIST_URL="${JADWAL_SHOLAT_ATHAN_LIST_URL:-https://alfurqan.online/api/v1/athan/list}"
JADWAL_SHOLAT_ATHAN_ID="${JADWAL_SHOLAT_ATHAN_ID:-1a014366658c}"
JADWAL_SHOLAT_ATHAN_URL="${JADWAL_SHOLAT_ATHAN_URL:-https://alfurqan.online/api/v1/athan/${JADWAL_SHOLAT_ATHAN_ID}}"
JADWAL_SHOLAT_RUNTIME_INTERVAL="${JADWAL_SHOLAT_RUNTIME_INTERVAL:-20}"
JADWAL_SHOLAT_ATHAN_ID_FILE="${JADWAL_SHOLAT_ATHAN_ID_FILE:-.athan_id}"
JADWAL_SHOLAT_ATHAN_URL_FILE="${JADWAL_SHOLAT_ATHAN_URL_FILE:-.athan_url}"
JADWAL_SHOLAT_WEB_HOST="${JADWAL_SHOLAT_WEB_HOST:-127.0.0.1}"
JADWAL_SHOLAT_WEB_PORT="${JADWAL_SHOLAT_WEB_PORT:-8787}"
