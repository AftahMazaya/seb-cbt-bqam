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
- membuat ikon **Ujian CBT BQAM** berlogo pesantren (`cbt-bqam.ico`) di desktop
  semua pengguna.

Konfigurasi hanya berisi alamat login Moodle dan aturan penguncian SEB, jadi
dibiarkan terpasang untuk ujian berikutnya. Jalankan `PASANG-SEB.cmd` lagi
kapan saja untuk mengambil versi terbaru.

### Banyak PC tanpa internet cepat

Salin ke flashdisk: isi repo ini + `SEB_3.10.2.920_SetupBundle.exe` dari
[rilis resmi SEB](https://github.com/SafeExamBrowser/seb-win-refactoring/releases/tag/v3.10.2).
Skrip memakai pemasang di flashdisk dan tidak mengunduh ulang. Bila GitHub
tidak terjangkau sama sekali, `jadwal.json` dan `cbt-bqam.seb` di flashdisk
yang dipakai (sidiknya tetap diperiksa).

### Perintah lain

| Berkas / perintah | Gunanya |
|---|---|
| `HAPUS-KONFIGURASI.cmd` | hapus konfigurasi dan ikon (SEB tetap terpasang) |
| `pasang-seb.ps1 -Periksa` | lihat keadaan PC: versi SEB, konfigurasi, ikon |
| `pasang-seb.ps1 -Diam` | tanpa "tekan Enter" di akhir |

## Untuk panitia

**Mengubah konfigurasi atau sandi keluar:**

```
python3 buat-seb.py --sandi-acak
```

lalu unggah `cbt-bqam.seb` dan `jadwal.json` yang baru (`jadwal.json` berisi
sidik berkas `.seb`; pemasang menolak berkas yang sidiknya tidak cocok), dan
jalankan ulang `PASANG-SEB.cmd` di tiap PC. Sandi keluar hanya
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
