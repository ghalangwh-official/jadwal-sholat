# Runtime and Roadmap

Repo ini sekarang dibagi ke tiga boundary utama:

- `jadwal-sholat.sh` untuk UI interaktif dan fetching jadwal
- `runtime.sh` untuk monitor adzan otomatis
- `notif.sh` untuk notifikasi jadwal aktif
- `web.sh` untuk local web statis jadwal, Hijriyah, Quran, dan murotal

## Stable Contracts

- jadwal sumber utama: myQuran
- tafsir random: `https://api.myquran.com/v3/quran/random`
- audio adzan: Al Furqan endpoint, bisa dioverride via env
- state lokal disimpan di file repo, bukan di current directory

## Known Gaps

- belum ada daemon supervisor resmi seperti `termux-services`
- runtime masih polling, bukan scheduler event-driven
- belum ada UI selektor muezzin
- belum ada paket rilis terpisah untuk install/update
- web lokal masih static-first dan bergantung ke API CORS untuk refresh online

## Next Steps

- tambahkan `termux-services` wrapper opsional
- simpan pilihan kota dan muezzin ke config yang lebih formal
- tambahkan mode `test` yang lebih ketat untuk CI lokal
- buat release notes singkat per perubahan
