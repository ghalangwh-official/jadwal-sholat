#!/bin/env/bash

# Script ini dibuat untuk kita mengingat waktu sholat
# Saya hanya membuat script nya saja !

# Jika ada kendala eror Script atau API mati silahkan kontak saya
# Segala sumber API : myquran.com, quran-api-id.vercel.app, santrikoding.com .

required_packages=("jq" "fzf" "mpv" "axel" "curl" "shuf" "html2text")
# Fungsi untuk memeriksa apakah paket sudah terinstal dan menginstal jika belum
function check_and_install_package() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "Paket $1 tidak ditemukan. Menginstal paket..."
        # Perintah instalasi paket berdasarkan jenis sistem operasi
        if [[ -n $(command -v pkg) ]]; then
            pkg install -y "$@" &> /dev/null
        elif [[ -n $(command -v apt-get) ]]; then
            sudo apt-get install -y "$@" &> /dev/null
        elif [[ -n $(command -v yum) ]]; then
            sudo yum install -y "$@" &> /dev/null
        else
            echo -e "Sistem operasi tidak didukung. Silakan instal paket $1 secara manual."
            exit 1
        fi
    fi
}

# Memeriksa dan menginstal setiap paket dalam daftar
for package in "${required_packages[@]}"; do
    check_and_install_package "$package"
done

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

function print_banner() {
  echo -e "\n\n"
  colorful_text "╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮"
  colorful_text "┃              JADWAL SHOLAT                  ┃"
  colorful_text "┠─────────────────────────────────────────────┨"
  colorful_text "┃     Author: ghalangwh.official              ┃"
  colorful_text "┃     Medsos: @ghalangwh.official             ┃"
  colorful_text "┃ Report Bug: https://t.me/ghalangwh_official ┃"
  colorful_text "╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯"
  echo -e ""
}

function main_menu() {
    echo -n -e " [>] laang : "; read laang;

    if [[ -z ${laang} ]]; then
        echo -e " [!] “ help ” For more command to help you !"
    elif echo "${laang}" | grep -qi "exit"; then
        echo -e "\n [+] Terimakasih Telah Menggunakan Script ini !" | pv -qL 15
        exit
    elif echo "${laang}" | grep -qi "help"; then
        raw_help=("
[					]
      exit     - Keluar dari script
      clear    - refresh jadwal-sholat
      update   - Mengupdate lokasi
      murotal  - play murotal randomm
      download - download murotal only
[					]
")
    echo -e "\n${raw_help}\n"
    main_menu
    elif echo "${laang}" | grep -qi "clear"; then
        bash jadwal.sh
    elif echo "${laang}" | grep -qi "update"; then
        rm -rf .selected_id.dat
        bash jadwal.sh
    elif echo "${laang}" | grep -qi "Murotal"; then
        if echo "${laang}" | grep -qi "^Murotal [0-9]*$"; then
            surah_number=$(echo "${laang}" | grep -o "[0-9]*")
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
        curl -sL "https://quran-api.santrikoding.com/api/surah/${surah_number}" -o surah.json
        echo -e "     Nama Surah : $(jq -r '.nama_latin' surah.json) ($(jq -r '.arti' surah.json)) \n"
        mpv $(jq -r '.audio' surah.json)
        main_menu
    elif echo "${laang}" | grep -qi "download"; then
        if echo "${laang}" | grep -qi "^download [0-9]*$"; then
            surah_number=$(echo "${laang}" | grep -o "[0-9]*")
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
        curl -sL "https://quran-api.santrikoding.com/api/surah/${surah_number}" -o surah.json
        echo -e "     Nama Surah : $(jq -r '.nama_latin' surah.json) ($(jq -r '.arti' surah.json)) \n"
        mkdir -p download
        axel $(jq -r '.audio' surah.json) -o download
        echo -e "\n"
        echo -e " [•] Nama² file : $(ls download | sed ':a;N;$!ba;s/\n/, /g')"
        echo -e " [•] Jumlah file : $(ls download | wc -l)\n"
        # anda bisa memutar hasil download tersebut dengan cara
        # mpv nama-file.mp3
        main_menu
    else
        echo -e "\n [!] Invalid perintah tidak di temukan !"
        echo -e "     Ketik “ help ” Untuk melihat perintah \n"
        main_menu
    fi
}


if [ -f "list_kota.json" ]; then
    #echo -e " [+] File list_kota.json ditemukan."
    sleep 0.5
else
    echo -e " [!] File list_kota.json tidak ditemukan. Mendownload..."
    curl --silent --location "https://api.myquran.com/v2/sholat/kota/semua" | jq > list_kota.json
    sleep 1
fi

# Warna putih
p="\e[97m"   #putih

clear
if [ -f ".selected_id.dat" ]; then
  if $(wc -l .selected_id.dat | awk '{printf $1}') == "0";then
    curl --silent --location "https://api.myquran.com/v2/sholat/jadwal/$(cat .selected_id.dat)/$(date +%G-%m-%d)" | jq > jadwal_sholat.json
  fi
else
selected_id=$(jq -r '.data[] | " [+] \(.lokasi) - (\(.id))"' list_kota.json | fzf --prompt=" [?] Silahkan Pilih ID Kota/kab : "| grep -oP '(?<=\().*?(?=\))')
echo -e "${selected_id}" > .selected_id.dat

if [ -z "${selected_id}" ]; then
    echo -e " [!] ID Kota/Kabupaten tidak valid atau tidak dipilih."
    exit 1
fi
curl --silent --location "https://api.myquran.com/v2/sholat/jadwal/${selected_id}/$(date +%G-%m-%d)" | jq > jadwal_sholat.json
fi

 print_banner
echo -e "${p}"
echo -e " [+] ID : $(jq -r '.data.id' jadwal_sholat.json)"
echo -e " [+] Last Update : $(date)"
echo -e " [+] ID Kota/Kabupaten yang dipilih : $(jq -r '.data.daerah' jadwal_sholat.json), $(jq -r '.data.lokasi' jadwal_sholat.json)"
jadwal_sholat=("
[  		         		]
          [•] Subuh    : $(jq -r '.data.jadwal.subuh' jadwal_sholat.json)
          [•] Imsak    : $(jq -r '.data.jadwal.imsak' jadwal_sholat.json)
          [•] Terbit   : $(jq -r '.data.jadwal.terbit' jadwal_sholat.json)
          [•] Dhuha    : $(jq -r '.data.jadwal.dhuha' jadwal_sholat.json)
          [•] Dzuhur   : $(jq -r '.data.jadwal.dzuhur' jadwal_sholat.json)
          [•] Ashar    : $(jq -r '.data.jadwal.ashar' jadwal_sholat.json)
          [•] Maghrib  : $(jq -r '.data.jadwal.maghrib' jadwal_sholat.json)
          [•] Isya     : $(jq -r '.data.jadwal.isya' jadwal_sholat.json)
[         				]\n
          ")

echo -e " \n${jadwal_sholat} "
curl -s "https://quran-api-id.vercel.app/random" > random_quran.json

echo -e " Tafsir Random : “$(jq -r '.tafsir.kemenag.short' random_quran.json)” \n"

main_menu
