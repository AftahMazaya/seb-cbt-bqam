# SEB untuk CBT BQAM

Pemasang Safe Exam Browser (SEB) dan konfigurasi ujian untuk PC/laptop Windows
peserta CBT Pondok Pesantren Baitul Qur'an Al Jahra Magetan.

## Memasang di satu PC

1. Unduh repo ini: tombol hijau **Code → Download ZIP**, lalu ekstrak.
2. Klik dua kali **`PASANG-SEB.cmd`** dan setujui permintaan Administrator.
3. Tunggu sampai muncul **SIAP**. Di desktop muncul ikon **Ujian CBT BQAM**.

Skrip ini:

- memasang SEB 3.10.2 kalau belum ada atau versinya lama (unduhan ±360 MB,
  tanda tangan digital pemasang diperiksa dulu);
- mengunduh `cbt-bqam.seb` dan memeriksa sidik SHA-256-nya terhadap `jadwal.json`;
- membuat ikon di desktop semua pengguna;
- memasang tugas terjadwal yang tiap 15 menit dan tiap PC dinyalakan
  memeriksa repo ini: konfigurasi baru diambil otomatis, dan **konfigurasi
  serta ikon dihapus sendiri setelah waktu `berakhir` di `jadwal.json`**.
  SEB-nya tetap terpasang untuk ujian berikutnya.

### Banyak PC tanpa internet cepat

Salin ke flashdisk: isi repo ini + `SEB_3.10.2.920_SetupBundle.exe` dari
[rilis resmi SEB](https://github.com/SafeExamBrowser/seb-win-refactoring/releases/tag/v3.10.2).
Skrip memakai pemasang di flashdisk dan tidak mengunduh ulang. Bila GitHub
tidak terjangkau sama sekali, `jadwal.json` dan `cbt-bqam.seb` di flashdisk
yang dipakai (sidiknya tetap diperiksa).

### Perintah lain

| Berkas / perintah | Gunanya |
|---|---|
| `HAPUS-KONFIGURASI.cmd` | hapus konfigurasi, ikon, dan tugas sekarang juga |
| `pasang-seb.ps1 -Periksa` | lihat keadaan PC: versi SEB, konfigurasi, jadwal hapus |
| `pasang-seb.ps1 -Diam` | tanpa "tekan Enter" di akhir |

## Untuk panitia

**Mengubah jadwal hapus:** edit `jadwal.json` langsung di GitHub, ganti
`berakhir` (format `2026-10-31T17:00:00+07:00`, WIB). PC yang sudah terpasang
mengikutinya dalam 15 menit. Memasang di PC baru ditolak kalau jadwalnya sudah lewat.

**Mengubah konfigurasi atau sandi keluar:**

```
python3 buat-seb.py --sandi-acak --berakhir "2026-10-31 17:00"
```

lalu unggah `cbt-bqam.seb` dan `jadwal.json` yang baru. Sandi keluar hanya
ditampilkan sekali; repo ini publik, jadi yang tersimpan di berkas hanya
hash-nya. Jangan pernah mengunggah sandi itu sendiri.

**Pengaturan kuis di Moodle:** satu berkas ini dipakai untuk semua kuis, jadi
pada kuis yang wajib SEB, di bagian *Safe Exam Browser* isi *Require the use of
Safe Exam Browser* dengan **Yes – Use SEB client config**. Pilihan *Configure
manually*, *Use an existing template*, atau *Upload my own config* mengikat SEB
ke satu kuis dan menolak berkas ini. Peserta yang
memakai HP tidak bisa membuka kuis yang wajib SEB; untuk ruang campuran,
biarkan SEB tidak wajib dan pantau label **Komputer tanpa SEB** di Dashboard
Pengawas.

## Bila muncul "Prohibited Display Configuration"

Konfigurasi ini mengizinkan satu monitor eksternal, jadi PC dengan satu
monitor seharusnya lolos. Kalau masih muncul, buka log di
`%LocalAppData%\SafeExamBrowser\Logs` dan cari baris `Detected N active displays`.
Angka 2 di PC yang monitornya satu biasanya berarti kartu grafis melaporkan
dua keluaran aktif (HDMI dan VGA tersambung, atau proyektor): lepas kabel
yang tidak dipakai, atau di *Settings → Display* pilih *Show only on 1*.
