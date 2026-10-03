#Requires -Version 5.1
<#
  PASANG SEB - CBT Pondok Pesantren Baitul Qur'an Al Jahra
  ---------------------------------------------------------
  Menyiapkan satu PC/laptop Windows untuk ujian CBT:
    1. memasang Safe Exam Browser bila belum ada (atau versinya terlalu lama),
    2. mengunduh konfigurasi ujian (.seb) dari repo GitHub panitia dan
       memeriksa sidik SHA-256-nya,
    3. membuat ikon "Ujian CBT BQAM" di desktop semua pengguna.

  Konfigurasi hanya berisi alamat login Moodle dan aturan penguncian, jadi
  dibiarkan terpasang untuk ujian berikutnya. Menjalankan skrip ini lagi
  mengambil versi terbaru dari repo.

  Cara pakai: klik dua kali PASANG-SEB.cmd (akan meminta izin Administrator).
    pasang-seb.ps1             pasang / perbarui
    pasang-seb.ps1 -Periksa    tampilkan keadaan PC ini
    pasang-seb.ps1 -Hapus      hapus konfigurasi dan ikon (SEB tetap terpasang)
    pasang-seb.ps1 -Diam       tanpa "tekan Enter" di akhir (untuk banyak PC)

  Tanpa internet: taruh SEB_*_SetupBundle.exe, cbt-bqam.seb, cbt-bqam.ico, dan jadwal.json
  di folder yang sama dengan skrip ini (misalnya di flashdisk).
#>
param([switch]$Periksa, [switch]$Hapus, [switch]$Diam)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ---------------- setelan (ubah di sini bila repo pindah) ----------------
$REPO_RAW    = 'https://raw.githubusercontent.com/AftahMazaya/seb-cbt-bqam/main'
$SEB_MIN     = [version]'3.10.0'
$SEB_BUNDLE  = 'SEB_3.10.2.920_SetupBundle.exe'
$SEB_URL     = "https://github.com/SafeExamBrowser/seb-win-refactoring/releases/download/v3.10.2/$SEB_BUNDLE"
$DIR         = Join-Path $env:ProgramData 'CBT-BQAM'
# Tugas terjadwal dari versi lama skrip ini (penghapusan otomatis). Dibuang
# bila masih ada.
$TUGAS_LAMA  = 'CBT BQAM - Perbarui atau hapus konfigurasi SEB'
# --------------------------------------------------------------------------

$SINI = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

function Tulis([string]$teks, [string]$warna = 'Gray') { Write-Host $teks -ForegroundColor $warna }
function Judul([string]$teks) { Write-Host ''; Write-Host "=== $teks ===" -ForegroundColor Cyan }
function Selesai([int]$kode) {
    if (-not $Diam) { Write-Host ''; Read-Host 'Tekan Enter untuk menutup' | Out-Null }
    exit $kode
}

# ---------------- hak Administrator ----------------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    if ($PSCommandPath) {
        $arg = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        if ($Periksa) { $arg += '-Periksa' }
        if ($Hapus)   { $arg += '-Hapus' }
        if ($Diam)    { $arg += '-Diam' }
        try { Start-Process powershell.exe -Verb RunAs -ArgumentList $arg | Out-Null }
        catch { Tulis 'Izin Administrator ditolak. Skrip tidak dijalankan.' Red; Selesai 1 }
        exit 0
    }
    Tulis 'Jalankan PowerShell sebagai Administrator, lalu ulangi perintahnya.' Red
    Selesai 1
}

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
New-Item -ItemType Directory -Force -Path $DIR | Out-Null
$LOG = Join-Path $DIR 'log.txt'
function Catat([string]$teks) { Add-Content -Path $LOG -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $teks) -Encoding UTF8 }

$SEB_CFG   = Join-Path $DIR 'cbt-bqam.seb'
$IKON      = Join-Path $DIR 'cbt-bqam.ico'
$DESKTOP   = [Environment]::GetFolderPath('CommonDesktopDirectory')

function Cari-SEB {
    foreach ($akar in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $akar) { continue }
        $p = Join-Path $akar 'SafeExamBrowser\Application\SafeExamBrowser.exe'
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Versi-SEB([string]$exe) {
    try { return [version]((Get-Item $exe).VersionInfo.ProductVersion -replace '[^0-9.].*$', '') } catch { return [version]'0.0' }
}

# raw.githubusercontent.com melayani text/plain; Invoke-RestMethod di
# PowerShell 5.1 tidak selalu mengubahnya jadi objek, jadi diurai sendiri.
function Ambil-Json([string]$url) {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -Headers @{ 'Cache-Control' = 'no-cache' }
    return ($r.Content | ConvertFrom-Json)
}

function Pintasan-Path([string]$nama) { Join-Path $DESKTOP ("$nama.lnk") }

# Sisa versi lama: tugas penghapus otomatis dan skripnya.
function Buang-Sisa-Lama {
    if (Get-ScheduledTask -TaskName $TUGAS_LAMA -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TUGAS_LAMA -Confirm:$false
        Tulis '  tugas penghapus otomatis versi lama dibuang'
        Catat 'tugas penghapus otomatis versi lama dibuang'
    }
    foreach ($f in @('penjaga.ps1', 'jadwal.json')) {
        $p = Join-Path $DIR $f
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- -Periksa ----------------
if ($Periksa) {
    Judul 'Keadaan PC ini'
    $exe = Cari-SEB
    if ($exe) { Tulis ("  SEB         : {0}  (versi {1})" -f $exe, (Versi-SEB $exe)) Green } else { Tulis '  SEB         : BELUM TERPASANG' Yellow }
    if (Test-Path $SEB_CFG) {
        Tulis ("  Konfigurasi : {0}  (sidik {1})" -f $SEB_CFG, (Get-FileHash $SEB_CFG -Algorithm SHA256).Hash.Substring(0, 12).ToLower())
    } else { Tulis '  Konfigurasi : tidak ada' Yellow }
    $ikon = Get-ChildItem -Path $DESKTOP -Filter '*.lnk' -ErrorAction SilentlyContinue |
            Where-Object { (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).Arguments -like "*$SEB_CFG*" }
    Tulis ("  Ikon        : {0}" -f $(if ($ikon) { ($ikon | ForEach-Object Name) -join ', ' } else { 'tidak ada' }))
    if (Get-ScheduledTask -TaskName $TUGAS_LAMA -ErrorAction SilentlyContinue) {
        Tulis '  Tugas lama  : masih ada (jalankan PASANG-SEB.cmd sekali lagi untuk membuangnya)' Yellow
    }
    Selesai 0
}

# ---------------- -Hapus ----------------
if ($Hapus) {
    Judul 'Menghapus konfigurasi ujian dari PC ini'
    Get-ChildItem -Path $DESKTOP -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
        if ((New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).Arguments -like "*$SEB_CFG*") {
            Remove-Item $_.FullName -Force; Tulis "  dihapus: $($_.FullName)"
        }
    }
    foreach ($f in @($SEB_CFG, $IKON)) { if (Test-Path $f) { Remove-Item $f -Force; Tulis "  dihapus: $f" } }
    Buang-Sisa-Lama
    Catat 'hapus: diminta panitia (-Hapus)'
    Tulis '  Selesai. Safe Exam Browser tetap terpasang.' Green
    Selesai 0
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  PASANG SEB - CBT Baitul Qur''an Al Jahra' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

# ---------------- 1. daftar berkas ----------------
# jadwal.json di repo memuat nama berkas .seb dan sidik SHA-256-nya.
# (Kolom "berakhir" peninggalan versi lama tidak dipakai lagi.)
Judul '1. Membaca daftar berkas dari repo panitia'
$jadwal = $null
try {
    $jadwal = Ambil-Json "$REPO_RAW/jadwal.json"
    Tulis "  diambil dari GitHub" Green
} catch {
    $lokal = Join-Path $SINI 'jadwal.json'
    if (Test-Path $lokal) {
        $jadwal = Get-Content $lokal -Raw -Encoding UTF8 | ConvertFrom-Json
        Tulis "  GitHub tidak terjangkau, memakai jadwal.json di folder ini" Yellow
    }
}
if (-not $jadwal -or -not $jadwal.berkas -or -not $jadwal.sha256) {
    Tulis '  BERHENTI: jadwal.json tidak dapat dibaca. Periksa internet, atau salin jadwal.json ke folder skrip ini.' Red
    Selesai 1
}

# ---------------- 2. Safe Exam Browser ----------------
Judul '2. Safe Exam Browser'
$exe = Cari-SEB
if ($exe -and (Versi-SEB $exe) -ge $SEB_MIN) {
    Tulis ("  sudah terpasang, versi {0}" -f (Versi-SEB $exe)) Green
} else {
    if ($exe) { Tulis ("  versi {0} terlalu lama, diperbarui ke {1}" -f (Versi-SEB $exe), $SEB_MIN) Yellow }
    if ([Environment]::OSVersion.Version.Build -lt 17134) {
        Tulis '  BERHENTI: SEB 3.10 butuh Windows 10 versi 1803 atau lebih baru.' Red
        Selesai 1
    }
    $pemasang = Get-ChildItem -Path $SINI -Filter 'SEB_*_SetupBundle.exe' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($pemasang) {
        $pemasang = $pemasang.FullName
        Tulis "  memakai pemasang di folder ini: $(Split-Path $pemasang -Leaf)"
    } else {
        $pemasang = Join-Path $env:TEMP $SEB_BUNDLE
        if (-not (Test-Path $pemasang) -or (Get-Item $pemasang).Length -lt 100MB) {
            Tulis "  mengunduh $SEB_BUNDLE (sekitar 360 MB, bisa beberapa menit)..."
            try {
                Import-Module BitsTransfer -ErrorAction Stop
                Start-BitsTransfer -Source $SEB_URL -Destination $pemasang -DisplayName 'Safe Exam Browser'
            } catch {
                Invoke-WebRequest -Uri $SEB_URL -OutFile $pemasang -UseBasicParsing
            }
        }
    }
    # Pemasang resmi ditandatangani ETH Zurich. Tanda tangan rusak = berkas
    # tidak utuh atau bukan dari pembuat SEB: jangan dijalankan.
    $tt = Get-AuthenticodeSignature -FilePath $pemasang
    if ($tt.Status -ne 'Valid') {
        Tulis "  BERHENTI: tanda tangan pemasang tidak sah ($($tt.Status)). Hapus berkasnya dan unduh ulang." Red
        Remove-Item $pemasang -Force -ErrorAction SilentlyContinue
        Selesai 1
    }
    Tulis ("  tanda tangan sah: {0}" -f ($tt.SignerCertificate.Subject -replace ',.*$', ''))
    Tulis '  memasang (tanpa jendela, 2-5 menit)...'
    $p = Start-Process -FilePath $pemasang -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
    if (@(0, 1641, 3010) -notcontains $p.ExitCode) {
        Tulis "  BERHENTI: pemasangan gagal (kode $($p.ExitCode)). Coba jalankan $(Split-Path $pemasang -Leaf) secara manual." Red
        Catat "pasang SEB gagal, kode $($p.ExitCode)"
        Selesai 1
    }
    $exe = Cari-SEB
    if (-not $exe) { Tulis '  BERHENTI: SEB belum ditemukan setelah dipasang.' Red; Selesai 1 }
    Tulis ("  terpasang, versi {0}" -f (Versi-SEB $exe)) Green
    if (@(1641, 3010) -contains $p.ExitCode) { Tulis '  PC perlu dinyalakan ulang sebelum ujian.' Yellow }
    Catat "SEB terpasang $(Versi-SEB $exe)"
}

# ---------------- 3. konfigurasi ujian ----------------
Judul '3. Konfigurasi ujian (.seb)'
$sementara = Join-Path $env:TEMP ('cbt-bqam-' + [guid]::NewGuid().ToString('N') + '.seb')
$asal = 'GitHub'
try {
    Invoke-WebRequest -Uri "$REPO_RAW/$($jadwal.berkas)" -OutFile $sementara -UseBasicParsing -TimeoutSec 60 -Headers @{ 'Cache-Control' = 'no-cache' }
} catch {
    $lokal = Join-Path $SINI $jadwal.berkas
    if (-not (Test-Path $lokal)) { Tulis '  BERHENTI: konfigurasi tidak dapat diunduh dan tidak ada salinan di folder ini.' Red; Selesai 1 }
    Copy-Item $lokal $sementara -Force
    $asal = 'folder ini'
}
$sidik = (Get-FileHash -Path $sementara -Algorithm SHA256).Hash.ToLower()
if ($sidik -ne $jadwal.sha256.ToLower()) {
    Remove-Item $sementara -Force
    Tulis '  BERHENTI: sidik konfigurasi tidak cocok dengan jadwal.json. Berkas rusak atau bukan versi panitia.' Red
    Catat "sidik tidak cocok: $sidik"
    Selesai 1
}
Move-Item $sementara $SEB_CFG -Force
# Siswa boleh membaca konfigurasi, tapi tidak boleh mengganti atau menghapusnya.
& icacls.exe $DIR /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
Tulis "  tersimpan: $SEB_CFG (dari $asal, sidik cocok)" Green

# ---------------- 4. ikon desktop ----------------
Judul '4. Ikon di desktop'
# Logo pesantren dari repo. Gagal diunduh atau sidiknya tidak cocok: pakai
# ikon bawaan SEB saja, pemasangan tetap lanjut.
$gambar = "$exe,0"
if ($jadwal.ikon -and $jadwal.ikon_sha256) {
    $tmpIkon = Join-Path $env:TEMP ('cbt-bqam-' + [guid]::NewGuid().ToString('N') + '.ico')
    try {
        Invoke-WebRequest -Uri "$REPO_RAW/$($jadwal.ikon)" -OutFile $tmpIkon -UseBasicParsing -TimeoutSec 60
    } catch {
        $lokal = Join-Path $SINI $jadwal.ikon
        if (Test-Path $lokal) { Copy-Item $lokal $tmpIkon -Force }
    }
    if ((Test-Path $tmpIkon) -and (Get-FileHash $tmpIkon -Algorithm SHA256).Hash.ToLower() -eq $jadwal.ikon_sha256.ToLower()) {
        Move-Item $tmpIkon $IKON -Force
        $gambar = "$IKON,0"
    } else {
        if (Test-Path $tmpIkon) { Remove-Item $tmpIkon -Force }
        Tulis '  logo tidak dapat diambil, memakai ikon bawaan SEB' Yellow
    }
}
$nama = if ($jadwal.nama_pintasan) { $jadwal.nama_pintasan } else { 'Ujian CBT BQAM' }
$lnk = Pintasan-Path $nama
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.Arguments = "`"$SEB_CFG`""
$sc.WorkingDirectory = Split-Path $exe
$sc.IconLocation = $gambar
$sc.Description = 'Buka ujian CBT di Safe Exam Browser'
$sc.Save()
Tulis "  dibuat: $lnk" Green

# ---------------- 5. rapikan sisa versi lama ----------------
Buang-Sisa-Lama
Catat "pasang selesai, sidik $sidik"

Write-Host ''
Write-Host '  SIAP. Peserta membuka ujian lewat ikon di desktop:' -ForegroundColor Green
Write-Host "    $nama" -ForegroundColor Green
Write-Host '  Keluar dari SEB membutuhkan sandi dari pengawas.' -ForegroundColor Gray
Selesai 0