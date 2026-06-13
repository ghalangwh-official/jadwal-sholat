# jadwal-sholat

Script jadwal sholat sederhana untuk Termux (Android) — lengkap dengan jadwal harian, adzan otomatis, murotal, dan pencarian quran.

## Daftar Isi

- [Prerequisites](#prerequisites)
- [Instalasi](#instalasi)
- [Cara Pakai Cepat](#cara-pakai-cepat)
- [Daftar Perintah](#daftar-perintah)
- [Runtime Adzan Otomatis](#runtime-adzan-otomatis)
- [Konfigurasi](#konfigurasi)
- [Catatan API](#catatan-api)
- [Smoke Test](#smoke-test)
- [Roadmap](#roadmap)
- [Lisensi](#lisensi)

## Prerequisites

- `jq` — parsing JSON
- `curl` — request API
- `mpv` — pemutar audio adzan/murotal (opsional, fallback ke play-audio bawaan Termux)
- `git` — clone repo

Semua bisa diinstall lewat pkg:

```bash
pkg install jq curl mpv git -y
```

## Instalasi

```bash
pkg update && pkg upgrade -y
pkg install git -y
git clone https://github.com/ghalangwh-official/jadwal-sholat.git
cd jadwal-sholat
chmod +x jadwal-sholat.sh
bash jadwal-sholat.sh
```

## Cara Pakai Cepat

```bash
cd ~/jadwal-sholat
bash jadwal-sholat.sh            # masuk menu interaktif
bash jadwal-sholat.sh today      # jadwal sholat hari ini
bash jadwal-sholat.sh next       # jadwal sholat berikutnya
```

Pilih menu `help` untuk lihat semua command yang tersedia.

## Daftar Perintah

| Perintah | Deskripsi |
|---|---|
| `help` | Tampilkan semua command |
| `update` | Update script & data |
| `today` | Jadwal sholat hari ini |
| `next` | Jadwal sholat berikutnya |
| `city search <nama>` | Cari kode kota |
| `quran search <kata>` | Cari ayat quran |
| `quran ayat <surah> <ayat>` | Baca ayat tertentu |
| `tafseer <surah>` | Lihat tafsir surah |
| `athan list` | Lihat daftar suara adzan |
| `athan set <id>` | Pilih suara adzan |
| `athan show` | Lihat suara adzan terpilih |
| `athan random` | Adzan acak tiap waktu |
| `murotal` | Putar murotal |
| `download` | Download resource tambahan |
| `runtime bg` | Jalanin runtime di background |
| `runtime stop` | Hentikan runtime |
| `notif` | Kirim notifikasi adzan |

### Contoh

```bash
bash jadwal-sholat.sh today
bash jadwal-sholat.sh next
bash jadwal-sholat.sh city search semarang
bash jadwal-sholat.sh quran search cahaya
bash jadwal-sholat.sh quran ayat 2 255
bash jadwal-sholat.sh tafseer 2
bash jadwal-sholat.sh athan list
bash jadwal-sholat.sh athan set 1a014366658c
bash jadwal-sholat.sh athan show
bash jadwal-sholat.sh notif
```

## Runtime Adzan Otomatis

Script `runtime.sh` untuk monitor jadwal sholat dan putar adzan otomatis.

| Perintah | Deskripsi |
|---|---|
| `bash runtime.sh run` | Jalan di foreground |
| `bash runtime.sh bg` | Jalan di background |
| `bash runtime.sh stop` | Hentikan background monitor |
| `bash runtime.sh status` | Cek status monitor |

**Environment variable override:**

- `JADWAL_SHOLAT_ATHAN_URL` — URL audio adzan kustom
- `JADWAL_SHOLAT_ATHAN_ID` — ID suara adzan dari `athan list`
- `JADWAL_SHOLAT_DRY_RUN=1` — mode tes (tanpa bunyi)
- `JADWAL_SHOLAT_TEST_NOW=04:36` — simulasi waktu tertentu
- `JADWAL_SHOLAT_ONCE=1` — cek sekali lalu exit

**Contoh tes dry-run:**

```bash
JADWAL_SHOLAT_DRY_RUN=1 JADWAL_SHOLAT_TEST_NOW=04:36 JADWAL_SHOLAT_ONCE=1 bash runtime.sh run
```

## Konfigurasi

1. Salin `config.example.sh` ke `config.sh`:
   ```bash
   cp config.example.sh config.sh
   ```
2. Edit `config.sh` untuk override endpoint API atau audio adzan.
3. Semua script membaca `config.sh` otomatis kalau ada.

**File state utama:**

| File | Kegunaan |
|---|---|
| `jadwal_sholat.json` | Cache jadwal sholat |
| `list_kota.json` | Data daftar kota |
| `.selected_id.dat` | ID suara adzan terpilih |
| `.runtime.pid` | PID proses runtime background |
| `.runtime_last_played` | Waktu adzan terakhir diputar |
| `runtime.log` | Log runtime |

## Catatan API

- Kota: myQuran v3 (`/kabkota` endpoint)
- Jadwal sholat: myQuran v2 (stabil)
- Pencarian ayat: myQuran v3 (`/quran/search`)
- Tafsir random: `https://api.myquran.com/v3/quran/random`
- Tafsir surah & daftar athan: Al Furqan API
- Endpoint Vercel lama sudah **tidak dipakai**

## Smoke Test

Jalankan untuk verifikasi:

```bash
bash scripts/smoke.sh
```

Cek: syntax script, runtime dry-run, keberadaan config example.

## Roadmap

Lihat `docs/01_runtime_and_roadmap.md` untuk gap dan next step yang masih relevan.

## Lisensi

<!-- Ganti sesuai license yang lo pake, misal MIT / GNU / dll -->
Proyek ini dilisensikan di bawah [MIT License](LICENSE).
