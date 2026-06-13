#!/usr/bin/env bash

set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
STATE_DIR="$SCRIPT_DIR"
LIST_KOTA_FILE="$STATE_DIR/list_kota.json"
SELECTED_ID_FILE="$STATE_DIR/.selected_id.dat"
JADWAL_FILE="$STATE_DIR/jadwal_sholat.json"
RANDOM_QURAN_FILE="$STATE_DIR/random_quran.json"
SURAH_FILE="$STATE_DIR/surah.json"
DOWNLOAD_DIR="$STATE_DIR/download"
RUNTIME_SCRIPT="$STATE_DIR/runtime.sh"
WEB_SCRIPT="$STATE_DIR/web.sh"
CONFIG_FILE="$STATE_DIR/config.sh"
ATHAN_ID_FILE="$STATE_DIR/.athan_id"
ATHAN_URL_FILE="$STATE_DIR/.athan_url"
ATHAN_SUBUH_ID_FILE="$STATE_DIR/.athan_subuh_id"
ATHAN_SUBUH_URL_FILE="$STATE_DIR/.athan_subuh_url"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

ATHAN_URL_WAS_SET="${JADWAL_SHOLAT_ATHAN_URL+x}"

# Script ini dibuat untuk kita mengingat waktu sholat
# Saya hanya membuat script nya saja !

# Jika ada kendala eror Script atau API mati silahkan kontak saya
# Segala sumber API : myquran.com, santrikoding.com .

required_commands=("jq" "mpv" "axel" "curl" "pv" "shuf")

cleanup() {
    local exit_code=$?
    # Clean up any temporary files if needed
    [[ -n "${TEMP_FILE:-}" && -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
    exit $exit_code
}

trap cleanup EXIT INT TERM

die() {
    echo "Error: $1" >&2
    echo "  at ${BASH_SOURCE[1]:-unknown}:${BASH_LINENO[0]:-unknown} in ${FUNCNAME[1]:-main}" >&2
    exit 1
}

show_help() {
# Termux adalah target utama repo ini, jadi jalur instalasi dioptimalkan untuk `pkg`.
function check_and_install_package() {
    local command_name="$1"
    local package_name="$1"

    case "$command_name" in
        shuf)
            package_name="coreutils"
            ;;
    esac

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo -e "Paket $package_name tidak ditemukan. Menginstal paket..."
        if command -v pkg >/dev/null 2>&1; then
            pkg install -y "$package_name" >/dev/null 2>&1 || die "Gagal memasang $package_name"
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get install -y "$package_name" >/dev/null 2>&1 || die "Gagal memasang $package_name"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "$package_name" >/dev/null 2>&1 || die "Gagal memasang $package_name"
        else
            die "Sistem operasi tidak didukung. Silakan instal $package_name secara manual."
        fi
    fi
}

for command_name in "${required_commands[@]}"; do
    check_and_install_package "$command_name"
done

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

function post_json() {
    local url="$1"
    local payload="$2"
    local output_file="$3"
    local tmp_file
    tmp_file="$(mktemp "${output_file}.XXXXXX")" || return 1

    if ! curl -fsSL -H 'Content-Type: application/json' -d "$payload" "$url" | jq '.' >"$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$output_file"
}

function urlencode() {
    printf '%s' "$1" | jq -sRr @uri
}

function resolve_athan_url() {
    local athan_id="$1"
    printf 'https://alfurqan.online/api/v1/athan/%s' "$athan_id"
}

JADWAL_SHOLAT_KOTA_URL="${JADWAL_SHOLAT_KOTA_URL:-https://api.myquran.com/v3/sholat/kabkota/semua}"
JADWAL_SHOLAT_CITY_SEARCH_URL="${JADWAL_SHOLAT_CITY_SEARCH_URL:-https://api.myquran.com/v3/sholat/kabkota/cari}"
JADWAL_SHOLAT_JADWAL_URL="${JADWAL_SHOLAT_JADWAL_URL:-https://api.myquran.com/v2/sholat/jadwal}"
JADWAL_SHOLAT_QURAN_SEARCH_URL="${JADWAL_SHOLAT_QURAN_SEARCH_URL:-https://api.myquran.com/v3/quran/search}"
JADWAL_SHOLAT_QURAN_RANDOM_URL="${JADWAL_SHOLAT_QURAN_RANDOM_URL:-https://api.myquran.com/v3/quran/random}"
JADWAL_SHOLAT_TAFSEER_URL="${JADWAL_SHOLAT_TAFSEER_URL:-https://alfurqan.online/api/v1/tafseer}"
JADWAL_SHOLAT_ATHAN_LIST_URL="${JADWAL_SHOLAT_ATHAN_LIST_URL:-https://alfurqan.online/api/v1/athan/list}"
JADWAL_SHOLAT_ATHAN_ID="${JADWAL_SHOLAT_ATHAN_ID:-1a014366658c}"
JADWAL_SHOLAT_ATHAN_URL="${JADWAL_SHOLAT_ATHAN_URL:-$(resolve_athan_url "$JADWAL_SHOLAT_ATHAN_ID")}"
JADWAL_SHOLAT_SUBUH_ATHAN_ID="${JADWAL_SHOLAT_SUBUH_ATHAN_ID:-$JADWAL_SHOLAT_ATHAN_ID}"
JADWAL_SHOLAT_SUBUH_ATHAN_URL="${JADWAL_SHOLAT_SUBUH_ATHAN_URL:-$JADWAL_SHOLAT_ATHAN_URL}"

if [ -s "$ATHAN_ID_FILE" ]; then
    JADWAL_SHOLAT_ATHAN_ID="$(tr -d '\r\n' < "$ATHAN_ID_FILE")"
fi
if [ -s "$ATHAN_URL_FILE" ]; then
    JADWAL_SHOLAT_ATHAN_URL="$(tr -d '\r\n' < "$ATHAN_URL_FILE")"
elif [ -z "${ATHAN_URL_WAS_SET:-}" ]; then
    JADWAL_SHOLAT_ATHAN_URL="$(resolve_athan_url "$JADWAL_SHOLAT_ATHAN_ID")"
fi
if [ -s "$ATHAN_SUBUH_ID_FILE" ]; then
    JADWAL_SHOLAT_SUBUH_ATHAN_ID="$(tr -d '\r\n' < "$ATHAN_SUBUH_ID_FILE")"
fi
if [ -s "$ATHAN_SUBUH_URL_FILE" ]; then
    JADWAL_SHOLAT_SUBUH_ATHAN_URL="$(tr -d '\r\n' < "$ATHAN_SUBUH_URL_FILE")"
elif [ -z "${JADWAL_SHOLAT_SUBUH_ATHAN_URL:-}" ]; then
    JADWAL_SHOLAT_SUBUH_ATHAN_URL="$JADWAL_SHOLAT_ATHAN_URL"
fi

function save_athan_selection() {
    local athan_id="$1"
    local athan_url="$2"
    printf '%s' "$athan_id" > "$ATHAN_ID_FILE"
    printf '%s' "$athan_url" > "$ATHAN_URL_FILE"
}

function save_subuh_athan_selection() {
    local athan_id="$1"
    local athan_url="$2"
    printf '%s' "$athan_id" > "$ATHAN_SUBUH_ID_FILE"
    printf '%s' "$athan_url" > "$ATHAN_SUBUH_URL_FILE"
}

function current_athan_id() {
    printf '%s' "${JADWAL_SHOLAT_ATHAN_ID:-}"
}

function current_athan_url() {
    printf '%s' "${JADWAL_SHOLAT_ATHAN_URL:-}"
}

function current_subuh_athan_id() {
    printf '%s' "${JADWAL_SHOLAT_SUBUH_ATHAN_ID:-}"
}

function current_subuh_athan_url() {
    printf '%s' "${JADWAL_SHOLAT_SUBUH_ATHAN_URL:-}"
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
        (.data.jadwal | type == "object") and
        (.data.jadwal.subuh // empty) != ""
    ' "$JADWAL_FILE" >/dev/null 2>&1
}

function schedule_time() {
    local key="$1"
    jq -r --arg key "$key" '
        if (.data.jadwal[$key] // empty) != "" then
            .data.jadwal[$key]
        else
            (.data.jadwal | to_entries[0].value[$key] // empty)
        end
    ' "$JADWAL_FILE"
}

function schedule_lines() {
    cat <<EOF
[•] Subuh    : $(schedule_time subuh)
[•] Imsak    : $(schedule_time imsak)
[•] Terbit   : $(schedule_time terbit)
[•] Dhuha    : $(schedule_time dhuha)
[•] Dzuhur   : $(schedule_time dzuhur)
[•] Ashar    : $(schedule_time ashar)
[•] Maghrib  : $(schedule_time maghrib)
[•] Isya     : $(schedule_time isya)
EOF
}

function city_rows_from_json() {
    local source_file="$1"
    jq -r '.data[] | [.lokasi, .id] | @tsv' "$source_file"
}

function city_numeric_id_by_name() {
    local source_file="$1"
    local city_name="$2"
    jq -r --arg city "$city_name" '
        .data[]
        | select(.lokasi == $city)
        | .id
    ' "$source_file" | awk 'NF { print; exit }'
}

function pick_city_id_from_json() {
    local source_file="$1"
    local city_rows selection selected_id

    if [ -n "${JADWAL_SHOLAT_TEST_CITY_ID:-}" ]; then
        printf '%s\n' "$JADWAL_SHOLAT_TEST_CITY_ID"
        return 0
    fi

    city_rows="$(city_rows_from_json "$source_file")" || return 1
    if [ -z "$city_rows" ]; then
        return 1
    fi

    if [ -t 0 ] && [ -t 1 ] && command -v fzf >/dev/null 2>&1; then
        selection="$(
            printf '%s\n' "$city_rows" \
                | awk -F '\t' '{ printf " [+] %s - (%s)\n", $1, $2 }' \
                | fzf --prompt=" [?] Pilih kota : "
        )" || return 1
        selected_id="$(printf '%s\n' "$selection" | sed -n 's/.*(\(.*\)).*/\1/p')"
        [ -n "$selected_id" ] || return 1
        printf '%s\n' "$selected_id"
        return 0
    fi

    if [ -n "${JADWAL_SHOLAT_CITY_PICK_INDEX:-}" ]; then
        selected_id="$(printf '%s\n' "$city_rows" | sed -n "${JADWAL_SHOLAT_CITY_PICK_INDEX}p" | cut -f2)"
    else
        selected_id="$(printf '%s\n' "$city_rows" | head -n 1 | cut -f2)"
    fi

    [ -n "$selected_id" ] || return 1
    printf '%s\n' "$selected_id"
}

function city_name_by_id() {
    local source_file="$1"
    local city_id="$2"
    jq -r --arg id "$city_id" '.data[] | select(.id == $id) | .lokasi' "$source_file"
}

function schedule_date_label() {
    jq -r '
        if .data.jadwal.subuh then
            .data.jadwal | keys[0]
        else
            .request.path | split("/")[-1]
        end
    ' "$JADWAL_FILE" 2>/dev/null
}

function time_to_minutes() {
    local hm="$1"
    printf '%s' "$((10#${hm%:*} * 60 + 10#${hm#*:}))"
}

function show_next_prayer() {
    local now_minutes prayer time_minutes min_diff next_prayer next_time diff
    now_minutes="$(time_to_minutes "$(date +%H:%M)")"
    min_diff=""
    next_prayer=""
    next_time=""

    for prayer in subuh dzuhur ashar maghrib isya; do
        prayer_time="$(schedule_time "$prayer")"
        [ -z "$prayer_time" ] && continue
        time_minutes="$(time_to_minutes "$prayer_time")"
        if [ "$time_minutes" -ge "$now_minutes" ]; then
            diff=$((time_minutes - now_minutes))
            if [ -z "$min_diff" ] || [ "$diff" -lt "$min_diff" ]; then
                min_diff="$diff"
                next_prayer="$prayer"
                next_time="$prayer_time"
            fi
        fi
    done

    if [ -n "$next_prayer" ]; then
        echo -e " [+] Next : ${next_prayer} (${next_time}) dalam ${min_diff} menit"
    else
        echo -e " [+] Next : semua waktu utama hari ini sudah lewat"
    fi
}

function show_schedule_today() {
    echo -e " [+] ID : $(jq -r '.data.id' "$JADWAL_FILE")"
    echo -e " [+] Last Update : $(date)"
    echo -e " [+] ID Kota/Kabupaten yang dipilih : $(jq -r '.data.daerah' "$JADWAL_FILE"), $(jq -r '.data.lokasi' "$JADWAL_FILE")"
    echo -e " [+] Tanggal Jadwal : $(schedule_date_label)"
    echo -e " [+] Athan Aktif : $(current_athan_id)"
    echo -e " $(schedule_lines)"
    show_next_prayer
}

function show_city_search_results() {
    local keyword="$1"
    local tmp_file selected_id selected_city
    tmp_file="$(mktemp "$STATE_DIR/.city_search.XXXXXX")" || return 1
    fetch_json "${JADWAL_SHOLAT_CITY_SEARCH_URL}/$(urlencode "$keyword")" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mencari kota"
    }

    if ! jq -e '.data and (.data | length > 0)' "$tmp_file" >/dev/null 2>&1; then
        rm -f "$tmp_file"
        die "Tidak ada kota yang cocok"
    fi

    selected_id="$(pick_city_id_from_json "$tmp_file")"
    if [ -z "$selected_id" ]; then
        rm -f "$tmp_file"
        die "Kota tidak dipilih"
    fi

    selected_city="$(city_name_by_id "$tmp_file" "$selected_id")"
    selected_id="$(city_numeric_id_by_name "$LIST_KOTA_FILE" "$selected_city")"
    if [ -z "$selected_id" ]; then
        rm -f "$tmp_file"
        die "ID numerik kota tidak ditemukan untuk ${selected_city}"
    fi
    printf '%s\n' "$selected_id" > "$SELECTED_ID_FILE"
    fetch_json "${JADWAL_SHOLAT_JADWAL_URL}/${selected_id}/$(date +%F)" "$JADWAL_FILE" || die "Gagal mengambil jadwal sholat"
    if ! schedule_file_is_valid; then
        rm -f "$tmp_file"
        rm -f "$SELECTED_ID_FILE"
        die "Jadwal tidak valid dari API untuk ${selected_city} (${selected_id})"
    fi
    rm -f "$tmp_file"

    echo -e " [+] Kota dipilih: ${selected_city} (${selected_id})"
    show_schedule_today
}

function show_quran_search() {
    local keyword="$1"
    local tmp_file
    tmp_file="$(mktemp "$STATE_DIR/.quran_search.XXXXXX")" || return 1
    post_json "$JADWAL_SHOLAT_QURAN_SEARCH_URL" "$(jq -n --arg keyword "$keyword" '{keyword:$keyword,page:1,limit:5}')" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mencari ayat"
    }

    if ! jq -e '.data and (.data | length > 0)' "$tmp_file" >/dev/null 2>&1; then
        rm -f "$tmp_file"
        die "Ayat tidak ditemukan"
    fi

    echo -e " [•] Hasil pencarian: ${keyword}"
    jq -r '.data[] | " - \(.surah.name_latin) \(.surah_number):\(.ayah_number) | \(.translation)\n   Audio: \(.audio_url)"' "$tmp_file"
    rm -f "$tmp_file"
}

function show_quran_ayah() {
    local surah="$1"
    local ayah="$2"
    local tmp_file
    tmp_file="$(mktemp "$STATE_DIR/.quran_ayah.XXXXXX")" || return 1
    fetch_json "https://api.myquran.com/v3/quran/${surah}/${ayah}" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mengambil detail ayat"
    }

    echo -e " [•] Surah ${surah} Ayat ${ayah} ($(jq -r '.data.surah.name_latin' "$tmp_file"))"
    echo -e "     Arab      : $(jq -r '.data.arab' "$tmp_file")"
    echo -e "     Arti      : $(jq -r '.data.translation' "$tmp_file")"
    echo -e "     Tafsir    : $(jq -r '.data.tafsir.kemenag.short' "$tmp_file")"
    echo -e "     Audio     : $(jq -r '.data.audio_url' "$tmp_file")"
    rm -f "$tmp_file"
}

function show_tafseer() {
    local surah="$1"
    local tafseer_id="${2:-muyassar}"
    local tmp_file
    tmp_file="$(mktemp "$STATE_DIR/.tafseer.XXXXXX")" || return 1
    fetch_json "${JADWAL_SHOLAT_TAFSEER_URL}/${tafseer_id}/surah/${surah}" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mengambil tafsir"
    }

    echo -e " [•] Tafsir ${surah} (${tafseer_id})"
    jq -r '
        .surah.ayahs[]
        | " - Ayah \(.ayah): \(.text)"
    ' "$tmp_file"
    rm -f "$tmp_file"
}

function show_athan_list() {
    local filter_type="$1"
    local filter_value="$2"
    local tmp_file
    tmp_file="$(mktemp "$STATE_DIR/.athan_list.XXXXXX")" || return 1

    if [ -n "$filter_type" ] && [ -n "$filter_value" ]; then
        fetch_json "${JADWAL_SHOLAT_ATHAN_LIST_URL}?${filter_type}=$(urlencode "$filter_value")" "$tmp_file" || {
            rm -f "$tmp_file"
            die "Gagal mengambil daftar athan"
        }
    else
        fetch_json "$JADWAL_SHOLAT_ATHAN_LIST_URL" "$tmp_file" || {
            rm -f "$tmp_file"
            die "Gagal mengambil daftar athan"
        }
    fi

    echo -e " [•] Daftar athan"
    jq -r '.athans[] | " - \(.id) | \(.name) | \(.muezzin) | \(.location) | \(.audioUrl)"' "$tmp_file"
    rm -f "$tmp_file"
}

function set_athan_by_id() {
    local athan_id="$1"
    local tmp_file athan_url athan_name
    tmp_file="$(mktemp "$STATE_DIR/.athan_pick.XXXXXX")" || return 1
    fetch_json "$JADWAL_SHOLAT_ATHAN_LIST_URL" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mengambil daftar athan"
    }

    athan_url="$(jq -r --arg id "$athan_id" '.athans[] | select(.id == $id) | .audioUrl' "$tmp_file")"
    athan_name="$(jq -r --arg id "$athan_id" '.athans[] | select(.id == $id) | .name' "$tmp_file")"
    rm -f "$tmp_file"

    if [ -z "$athan_url" ] || [ "$athan_url" = "null" ]; then
        die "Athan id tidak ditemukan"
    fi

    athan_url="https://alfurqan.online${athan_url}"
    save_athan_selection "$athan_id" "$athan_url"
    JADWAL_SHOLAT_ATHAN_ID="$athan_id"
    JADWAL_SHOLAT_ATHAN_URL="$athan_url"
    echo -e " [+] Athan aktif: ${athan_name} (${athan_id})"
}

function set_subuh_athan_by_id() {
    local athan_id="$1"
    local tmp_file athan_url athan_name
    tmp_file="$(mktemp "$STATE_DIR/.athan_pick.XXXXXX")" || return 1
    fetch_json "$JADWAL_SHOLAT_ATHAN_LIST_URL" "$tmp_file" || {
        rm -f "$tmp_file"
        die "Gagal mengambil daftar athan"
    }

    athan_url="$(jq -r --arg id "$athan_id" '.athans[] | select(.id == $id) | .audioUrl' "$tmp_file")"
    athan_name="$(jq -r --arg id "$athan_id" '.athans[] | select(.id == $id) | .name' "$tmp_file")"
    rm -f "$tmp_file"

    if [ -z "$athan_url" ] || [ "$athan_url" = "null" ]; then
        die "Athan id tidak ditemukan"
    fi

    athan_url="https://alfurqan.online${athan_url}"
    save_subuh_athan_selection "$athan_id" "$athan_url"
    JADWAL_SHOLAT_SUBUH_ATHAN_ID="$athan_id"
    JADWAL_SHOLAT_SUBUH_ATHAN_URL="$athan_url"
    echo -e " [+] Athan subuh aktif: ${athan_name} (${athan_id})"
}

function show_current_athan() {
    echo -e " [+] Athan ID  : $(current_athan_id)"
    echo -e " [+] Athan URL : $(current_athan_url)"
    echo -e " [+] Athan Subuh ID  : $(current_subuh_athan_id)"
    echo -e " [+] Athan Subuh URL : $(current_subuh_athan_url)"
}

function generate_random_color() {
  colors=("31" "32" "33" "34" "35" "36")
  random_index=$((RANDOM % ${#colors[@]}))
  echo "${colors[$random_index]}"
}

function colorful_text() {
  text="$1"
  color_code=$(generate_random_color)
  echo -e "\e[1;${color_code}m$text\e[0m"
}

function show_schedule_notification() {
    if ! command -v termux-notification >/dev/null 2>&1; then
        return 0
    fi

    local notification_body
    notification_body=$(cat <<EOF
Subuh    : $(schedule_time subuh)
Imsak    : $(schedule_time imsak)
Dzuhur   : $(schedule_time dzuhur)
Ashar    : $(schedule_time ashar)
Maghrib  : $(schedule_time maghrib)
Isya     : $(schedule_time isya)
EOF
)

    termux-notification -t "Jadwal Sholat" -c "$notification_body" >/dev/null 2>&1 || true
}

function print_banner() {
  echo -e "\n\n"
  colorful_text "╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮"
  colorful_text "┃              JADWAL SHOLAT                  ┃"
  colorful_text "┠─────────────────────────────────────────────┨"
  colorful_text "┃ runtime: adzan + kota + quran + tafseer     ┃"
  colorful_text "┃   author : ghalangwh.official               ┃"
  colorful_text "┃   bug    : t.me/ghalangwh_official          ┃"
  colorful_text "╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯"
  echo -e ""
}

function print_help() {
    cat <<'EOF'
 [•] help
     exit            keluar dari script
     clear           refresh tampilan
     update          ganti lokasi sholat
     today           tampilkan jadwal hari ini
     next            tampilkan jadwal berikutnya
     city search     cari dan pilih kota dari API
     quran search    cari ayat berdasarkan keyword
     quran ayat      tampilkan detail ayat
     tafseer         tampilkan tafsir surah
     athan list      lihat daftar athan
     athan set       pilih athan aktif
     athan subuh set pilih athan khusus subuh
     athan show      lihat athan aktif
     athan random    pilih athan acak
     murotal [n]     putar murotal random / nomor surah
     download [n]    download murotal random / nomor surah
     runtime start   jalankan monitor adzan di foreground
     runtime bg      jalankan monitor adzan di background
     runtime stop    hentikan monitor background
     runtime status   cek status monitor background
     notif           kirim notifikasi jadwal sekarang
     web             buka local web jadwal/quran/murotal
     web start       jalankan local web di foreground
     web bg          jalankan local web di background
     web stop        hentikan local web background
     web status      cek status local web background
EOF
}

function main_menu() {
    echo -n -e " [>] laang : "; read -r laang
    local cmd="${laang,,}"

    if [[ -z ${laang} ]]; then
        echo -e " [!] “ help ” For more command to help you !"
    elif [[ "$cmd" == "exit" ]]; then
        echo -e "\n [+] Terimakasih Telah Menggunakan Script ini !" | pv -qL 15
        exit
    elif [[ "$cmd" == "help" ]]; then
        echo
        print_help
        echo
        main_menu
    elif [[ "$cmd" == "clear" ]]; then
        exec bash "$SCRIPT_DIR/jadwal-sholat.sh"
    elif [[ "$cmd" == "update" ]]; then
        rm -f "$SELECTED_ID_FILE"
        exec bash "$SCRIPT_DIR/jadwal-sholat.sh"
    elif [[ "$cmd" == "today" ]]; then
        show_schedule_today
        main_menu
    elif [[ "$cmd" == "next" ]]; then
        show_next_prayer
        main_menu
    elif [[ "$cmd" == "notif" ]]; then
        show_schedule_notification
        main_menu
    elif [[ "$cmd" == "web" ]]; then
        bash "$WEB_SCRIPT" open
        main_menu
    elif [[ "$cmd" == "web start" ]]; then
        bash "$WEB_SCRIPT" run
        main_menu
    elif [[ "$cmd" == "web bg" ]]; then
        bash "$WEB_SCRIPT" bg
        main_menu
    elif [[ "$cmd" == "web stop" ]]; then
        bash "$WEB_SCRIPT" stop
        main_menu
    elif [[ "$cmd" == "web status" ]]; then
        bash "$WEB_SCRIPT" status
        main_menu
    elif [[ "$cmd" == city\ search* ]]; then
        keyword="${laang#city search }"
        if [ -z "$keyword" ] || [ "$keyword" = "$laang" ]; then
            echo -e " [!] gunakan: city search <keyword>"
        else
            show_city_search_results "$keyword"
        fi
        main_menu
    elif [[ "$cmd" == quran\ search* ]]; then
        keyword="${laang#quran search }"
        if [ -z "$keyword" ] || [ "$keyword" = "$laang" ]; then
            echo -e " [!] gunakan: quran search <keyword>"
        else
            show_quran_search "$keyword"
        fi
        main_menu
    elif [[ "$cmd" == quran\ ayat* ]]; then
        set -- $laang
        shift 2
        if [ "$#" -lt 2 ]; then
            echo -e " [!] gunakan: quran ayat <surah> <ayah>"
        else
            show_quran_ayah "$1" "$2"
        fi
        main_menu
    elif [[ "$cmd" == tafseer* ]]; then
        set -- $laang
        if [ -z "${2:-}" ]; then
            echo -e " [!] gunakan: tafseer <surah> [tafseer_id]"
        else
            show_tafseer "${2}" "${3:-muyassar}"
        fi
        main_menu
    elif [[ "$cmd" == athan\ list* ]]; then
        rest="${laang#athan list }"
        case "$rest" in
            muezzin\ *)
                show_athan_list "muezzin" "${rest#muezzin }"
                ;;
            location\ *)
                show_athan_list "location" "${rest#location }"
                ;;
            *)
                show_athan_list "" ""
                ;;
        esac
        main_menu
    elif [[ "$cmd" == athan\ set* ]]; then
        athan_id="${laang#athan set }"
        if [ -z "$athan_id" ] || [ "$athan_id" = "$laang" ]; then
            echo -e " [!] gunakan: athan set <athan_id>"
        else
            set_athan_by_id "$athan_id"
        fi
        main_menu
    elif [[ "$cmd" == athan\ subuh\ set* ]]; then
        athan_id="${laang#athan subuh set }"
        if [ -z "$athan_id" ] || [ "$athan_id" = "$laang" ]; then
            echo -e " [!] gunakan: athan subuh set <athan_id>"
        else
            set_subuh_athan_by_id "$athan_id"
        fi
        main_menu
    elif [[ "$cmd" == athan\ show ]]; then
        show_current_athan
        main_menu
    elif [[ "$cmd" == athan\ random ]]; then
        tmp_file="$(mktemp "$STATE_DIR/.athan_random.XXXXXX")" || die "Gagal menyiapkan athan random"
        fetch_json "$JADWAL_SHOLAT_ATHAN_LIST_URL" "$tmp_file" || {
            rm -f "$tmp_file"
            die "Gagal mengambil daftar athan"
        }
        random_athan_id="$(jq -r '.athans[] | .id' "$tmp_file" | shuf -n 1)"
        rm -f "$tmp_file"
        if [ -z "$random_athan_id" ]; then
            die "Athan random tidak ditemukan"
        fi
        set_athan_by_id "$random_athan_id"
        main_menu
    elif [[ "$cmd" == "runtime" || "$cmd" == "runtime start" ]]; then
        bash "$RUNTIME_SCRIPT" start
        main_menu
    elif [[ "$cmd" == "runtime bg" ]]; then
        bash "$RUNTIME_SCRIPT" bg
        main_menu
    elif [[ "$cmd" == "runtime stop" ]]; then
        bash "$RUNTIME_SCRIPT" stop
        main_menu
    elif [[ "$cmd" == "runtime status" ]]; then
        bash "$RUNTIME_SCRIPT" status
        main_menu
    elif [[ "$cmd" == murotal* ]]; then
        if [[ "$cmd" =~ ^murotal[[:space:]]+[0-9]+$ ]]; then
            surah_number="${laang##* }"
            if [ "${surah_number}" -ge 1 ] && [ "${surah_number}" -le 114 ]; then
                echo -e "\n [+] Murotal Surah : ${surah_number}"
            else
                echo -e "\n [!] Nomor surah tidak valid. Silakan masukkan nomor surah antara 1 dan 114. \n"
                main_menu
                return 0
            fi
        else
            echo -e "\n [+] Murotal Random"
            surah_number=$(shuf -i 1-114 -n 1)
        fi
    fetch_json "https://quran-api.santrikoding.com/api/surah/${surah_number}" "$SURAH_FILE" || die "Gagal mengambil data murotal"
        echo -e "     Nama Surah : $(jq -r '.nama_latin' "$SURAH_FILE") ($(jq -r '.arti' "$SURAH_FILE")) \n"
        mpv "$(jq -r '.audio' "$SURAH_FILE")"
        main_menu
    elif [[ "$cmd" == download* ]]; then
        if [[ "$cmd" =~ ^download[[:space:]]+[0-9]+$ ]]; then
            surah_number="${laang##* }"
            if [ "${surah_number}" -ge 1 ] && [ "${surah_number}" -le 114 ]; then
                echo -e "\n [+] Download Murotal Surah : ${surah_number}"
            else
                echo -e "\n [!] Nomor surah tidak valid. Silakan masukkan nomor surah antara 1 dan 114. \n"
                main_menu
                return 0
            fi
        else
            echo -e "\n [+] Download Murotal Random"
            surah_number=$(shuf -i 1-114 -n 1)
        fi
        fetch_json "https://quran-api.santrikoding.com/api/surah/${surah_number}" "$SURAH_FILE" || die "Gagal mengambil data murotal"
        echo -e "     Nama Surah : $(jq -r '.nama_latin' "$SURAH_FILE") ($(jq -r '.arti' "$SURAH_FILE")) \n"
        mkdir -p "$DOWNLOAD_DIR"
        audio_url="$(jq -r '.audio' "$SURAH_FILE")"
        (
            cd "$DOWNLOAD_DIR" || exit 1
            axel "$audio_url"
        )
        echo -e "\n"
        echo -e " [•] Nama² file : $(find "$DOWNLOAD_DIR" -maxdepth 1 -type f | sed 's#.*/##' | paste -sd ', ' -)"
        echo -e " [•] Jumlah file : $(find "$DOWNLOAD_DIR" -maxdepth 1 -type f | wc -l)\n"
        # anda bisa memutar hasil download tersebut dengan cara
        # mpv nama-file.mp3
        main_menu
    else
        echo -e "\n [!] Invalid perintah tidak di temukan !"
        echo -e "     Ketik “ help ” Untuk melihat perintah \n"
        main_menu
    fi
}


if [ -f "$LIST_KOTA_FILE" ]; then
    sleep 0.5
else
    echo -e " [!] File list_kota.json tidak ditemukan. Mendownload..."
    fetch_json "$JADWAL_SHOLAT_KOTA_URL" "$LIST_KOTA_FILE" || die "Gagal mengambil daftar kota"
    sleep 1
fi

# Warna putih
p="\e[97m"   #putih

clear
if [ -s "$SELECTED_ID_FILE" ]; then
    selected_id="$(tr -d '\r\n' < "$SELECTED_ID_FILE")"
    if ! is_numeric_id "$selected_id"; then
        echo -e " [!] ID kota tersimpan tidak valid. Silakan pilih kota ulang."
        rm -f "$SELECTED_ID_FILE"
        selected_id=""
    fi
fi

if [ -n "${selected_id:-}" ]; then
    fetch_json "${JADWAL_SHOLAT_JADWAL_URL}/${selected_id}/$(date +%F)" "$JADWAL_FILE" || die "Gagal mengambil jadwal sholat"
    if ! schedule_file_is_valid; then
        echo -e " [!] Jadwal kota tersimpan tidak valid. Silakan pilih kota ulang."
        rm -f "$SELECTED_ID_FILE"
        selected_id=""
    fi
fi

if [ -z "${selected_id:-}" ]; then
    selected_id="$(pick_city_id_from_json "$LIST_KOTA_FILE")"
    if [ -z "${selected_id}" ]; then
        echo -e " [!] ID Kota/Kabupaten tidak valid atau tidak dipilih."
        exit 1
    fi
    printf '%s\n' "$selected_id" > "$SELECTED_ID_FILE"
    fetch_json "${JADWAL_SHOLAT_JADWAL_URL}/${selected_id}/$(date +%F)" "$JADWAL_FILE" || die "Gagal mengambil jadwal sholat"
    if ! schedule_file_is_valid; then
        rm -f "$SELECTED_ID_FILE"
        die "Jadwal tidak valid dari API untuk ID ${selected_id}"
    fi
fi

 print_banner
echo -e "${p}"
echo -e " [+] ID : $(jq -r '.data.id // empty' "$JADWAL_FILE")"
echo -e " [+] Last Update : $(date)"
    echo -e " [+] ID Kota/Kabupaten yang dipilih : $(jq -r '.data.daerah // empty' "$JADWAL_FILE"), $(jq -r '.data.lokasi // empty' "$JADWAL_FILE")"
if command -v date >/dev/null 2>&1; then
    echo -e ' [+] Kalender Hijriyah : lihat di local web via `bash web.sh open`'
fi
jadwal_sholat=("
[  		         		]
          [•] Subuh    : $(jq -r '.data.jadwal.subuh' "$JADWAL_FILE")
          [•] Imsak    : $(jq -r '.data.jadwal.imsak' "$JADWAL_FILE")
          [•] Terbit   : $(jq -r '.data.jadwal.terbit' "$JADWAL_FILE")
          [•] Dhuha    : $(jq -r '.data.jadwal.dhuha' "$JADWAL_FILE")
          [•] Dzuhur   : $(jq -r '.data.jadwal.dzuhur' "$JADWAL_FILE")
          [•] Ashar    : $(jq -r '.data.jadwal.ashar' "$JADWAL_FILE")
          [•] Maghrib  : $(jq -r '.data.jadwal.maghrib' "$JADWAL_FILE")
          [•] Isya     : $(jq -r '.data.jadwal.isya' "$JADWAL_FILE")
[         				]\n
          ")

echo -e " \n${jadwal_sholat} "
fetch_json "$JADWAL_SHOLAT_QURAN_RANDOM_URL" "$RANDOM_QURAN_FILE" || die "Gagal mengambil tafsir random"
echo -e " Tafsir Random : “$(jq -r '.data.tafsir.kemenag.short // .tafsir.kemenag.short // empty' "$RANDOM_QURAN_FILE")” \n"

show_schedule_notification

main_menu
