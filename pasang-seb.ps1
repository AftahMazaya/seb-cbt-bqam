#Requires -Version 5.1
<#
  PASANG SEB - CBT Pondok Pesantren Baitul Qur'an Al Jahra
  ---------------------------------------------------------
  Menyiapkan satu PC/laptop Windows untuk ujian CBT:
    1. memasang Safe Exam Browser bila belum ada (atau versinya terlalu lama),
    2. mengunduh konfigurasi ujian (.seb) dari repo GitHub panitia dan
       memeriksa sidik SHA-256-nya,
    3. membuat ikon "Ujian CBT BQAM" di desktop semua pengguna,
    4. memasang tugas terjadwal yang memperbarui konfigurasi bila panitia
       mengubahnya, lalu MENGHAPUS konfigurasi dan ikon begitu jadwal ujian
       berakhir (SEB sendiri tetap terpasang).

  Cara pakai: klik dua kali PASANG-SEB.cmd (akan meminta izin Administrator).
    pasang-seb.ps1             pasang / perbarui
    pasang-seb.ps1 -Periksa    tampilkan keadaan PC ini
    pasang-seb.ps1 -Hapus      hapus konfigurasi, ikon, dan tugas sekarang juga
    pasang-seb.ps1 -Diam       tanpa "tekan Enter" di akhir (untuk banyak PC)

  Tanpa internet: taruh SEB_*_SetupBundle.exe, cbt-bqam.seb, dan jadwal.json
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
$TUGAS       = 'CBT BQAM - Perbarui atau hapus konfigurasi SEB'
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
$JADWAL    = Join-Path $DIR 'jadwal.json'
$PENJAGA   = Join-Path $DIR 'penjaga.ps1'
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
function Waktu($iso) {
    # PowerShell 7 sudah mengubah teks ISO menjadi DateTime; 5.1 belum.
    if ($iso -is [datetime]) { return [DateTimeOffset]$iso }
    return [DateTimeOffset]::Parse([string]$iso, [Globalization.CultureInfo]::InvariantCulture)
}

function Pintasan-Path([string]$nama) { Join-Path $DESKTOP ("$nama.lnk") }

function Hapus-Semua([string]$sebab) {
    $nama = 'Ujian CBT BQAM'
    if (Test-Path $JADWAL) { try { $nama = (Get-Content $JADWAL -Raw -Encoding UTF8 | ConvertFrom-Json).nama_pintasan } catch {} }
    foreach ($f in @($SEB_CFG, (Pintasan-Path $nama), $JADWAL, $PENJAGA)) {
        if ($f -and (Test-Path $f)) { Remove-Item $f -Force -ErrorAction SilentlyContinue; Tulis "  dihapus: $f" }
    }
    if (Get-ScheduledTask -TaskName $TUGAS -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TUGAS -Confirm:$false
        Tulis "  tugas terjadwal dihapus"
    }
    Catat "hapus: $sebab"
}

# ---------------- -Periksa ----------------
if ($Periksa) {
    Judul 'Keadaan PC ini'
    $exe = Cari-SEB
    if ($exe) { Tulis ("  SEB         : {0}  (versi {1})" -f $exe, (Versi-SEB $exe)) Green } else { Tulis '  SEB         : BELUM TERPASANG' Yellow }
    Tulis ("  Konfigurasi : {0}" -f $(if (Test-Path $SEB_CFG) { $SEB_CFG } else { 'tidak ada' }))
    if (Test-Path $JADWAL) {
        $j = Get-Content $JADWAL -Raw -Encoding UTF8 | ConvertFrom-Json
        Tulis ("  Dihapus pada: {0}" -f ((Waktu $j.berakhir).LocalDateTime))
        Tulis ("  Ikon        : {0}" -f $(if (Test-Path (Pintasan-Path $j.nama_pintasan)) { 'ada' } else { 'tidak ada' }))
    }
    $t = Get-ScheduledTask -TaskName $TUGAS -ErrorAction SilentlyContinue
    Tulis ("  Tugas       : {0}" -f $(if ($t) { $t.State } else { 'tidak ada' }))
    Selesai 0
}

# ---------------- -Hapus ----------------
if ($Hapus) {
    Judul 'Menghapus konfigurasi ujian dari PC ini'
    Hapus-Semua 'diminta panitia (-Hapus)'
    Tulis '  Selesai. Safe Exam Browser tetap terpasang.' Green
    Selesai 0
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  PASANG SEB - CBT Baitul Qur''an Al Jahra' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

# ---------------- 1. jadwal ----------------
Judul '1. Membaca jadwal dari repo panitia'
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
if (-not $jadwal -or -not $jadwal.berakhir -or -not $jadwal.sha256) {
    Tulis '  BERHENTI: jadwal.json tidak dapat dibaca. Periksa internet, atau salin jadwal.json ke folder skrip ini.' Red
    Selesai 1
}
$akhir = Waktu $jadwal.berakhir
Tulis ("  konfigurasi akan dihapus otomatis: {0:dddd, dd MMMM yyyy HH:mm}" -f $akhir.LocalDateTime)
if ([DateTimeOffset]::Now -ge $akhir) {
    Tulis '  BERHENTI: jadwal ujian di repo sudah lewat. Panitia perlu memperbarui jadwal.json dulu.' Red
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
$jadwal | ConvertTo-Json | Set-Content -Path $JADWAL -Encoding UTF8
Tulis "  tersimpan: $SEB_CFG (dari $asal, sidik cocok)" Green

# ---------------- 4. ikon desktop ----------------
Judul '4. Ikon di desktop'
$nama = if ($jadwal.nama_pintasan) { $jadwal.nama_pintasan } else { 'Ujian CBT BQAM' }
$lnk = Pintasan-Path $nama
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.Arguments = "`"$SEB_CFG`""
$sc.WorkingDirectory = Split-Path $exe
$sc.IconLocation = "$exe,0"
$sc.Description = 'Buka ujian CBT di Safe Exam Browser'
$sc.Save()
Tulis "  dibuat: $lnk" Green

# ---------------- 5. penjaga terjadwal ----------------
Judul '5. Penghapusan otomatis sesuai jadwal'
# Penjaga TIDAK pernah mengunduh atau menjalankan skrip. Ia hanya membaca
# jadwal.json, mengganti berkas .seb bila panitia memperbaruinya (sidiknya
# diperiksa), dan menghapus konfigurasi + ikon setelah jadwal berakhir.
$isiPenjaga = @'
$ErrorActionPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$REPO_RAW = '__REPO__'; $DIR = '__DIR__'; $TUGAS = '__TUGAS__'
$CFG = Join-Path $DIR 'cbt-bqam.seb'; $JADWAL = Join-Path $DIR 'jadwal.json'; $LOG = Join-Path $DIR 'log.txt'
function Catat($t) { Add-Content -Path $LOG -Value ("{0:yyyy-MM-dd HH:mm:ss}  penjaga: {1}" -f (Get-Date), $t) -Encoding UTF8 }
$j = $null
if (Test-Path $JADWAL) { $j = Get-Content $JADWAL -Raw -Encoding UTF8 | ConvertFrom-Json }
try {
    $baru = (Invoke-WebRequest -Uri "$REPO_RAW/jadwal.json" -UseBasicParsing -TimeoutSec 20 -Headers @{ 'Cache-Control' = 'no-cache' }).Content | ConvertFrom-Json
    if ($baru.berakhir -and $baru.sha256) {
        if ($j -and $baru.sha256 -ne $j.sha256) {
            $tmp = "$CFG.baru"
            Invoke-WebRequest -Uri "$REPO_RAW/$($baru.berkas)" -OutFile $tmp -UseBasicParsing -TimeoutSec 60
            if ((Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower() -eq $baru.sha256.ToLower()) {
                Move-Item $tmp $CFG -Force; Catat 'konfigurasi diperbarui dari repo'
            } else { Remove-Item $tmp -Force; Catat 'konfigurasi baru ditolak: sidik tidak cocok'; $baru.sha256 = $j.sha256 }
        }
        if (-not $j -or $baru.berakhir -ne $j.berakhir) { Catat "jadwal: $($baru.berakhir)" }
        $j = $baru
        $j | ConvertTo-Json | Set-Content -Path $JADWAL -Encoding UTF8
    }
} catch {}
if (-not $j) { exit 0 }
if ([DateTimeOffset]::Now -lt [DateTimeOffset]::Parse($j.berakhir, [Globalization.CultureInfo]::InvariantCulture)) { exit 0 }
$lnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) ("$($j.nama_pintasan).lnk")
foreach ($f in @($CFG, $lnk, $JADWAL)) { if (Test-Path $f) { Remove-Item $f -Force } }
Catat "jadwal berakhir ($($j.berakhir)), konfigurasi dan ikon dihapus"
Unregister-ScheduledTask -TaskName $TUGAS -Confirm:$false
Remove-Item $MyInvocation.MyCommand.Path -Force
'@
$isiPenjaga = $isiPenjaga.Replace('__REPO__', $REPO_RAW).Replace('__DIR__', $DIR).Replace('__TUGAS__', $TUGAS)
Set-Content -Path $PENJAGA -Value $isiPenjaga -Encoding UTF8

# Hanya Administrator dan SYSTEM yang boleh mengubah folder ini: penjaga
# berjalan sebagai SYSTEM, jadi skripnya tidak boleh bisa diganti siswa.
& icacls.exe $DIR /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null

$aksi = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PENJAGA`""
$pemicu = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)),
    (New-ScheduledTaskTrigger -Once -At $akhir.LocalDateTime)
)
$atur = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$siapa = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $TUGAS -Action $aksi -Trigger $pemicu -Settings $atur -Principal $siapa -Force | Out-Null
Tulis "  tugas terjadwal terpasang: memeriksa repo tiap 15 menit dan saat PC dinyalakan" Green
Tulis ("  konfigurasi + ikon hilang sendiri setelah {0:dd/MM/yyyy HH:mm}" -f $akhir.LocalDateTime) Green
Catat "pasang selesai, berakhir $($jadwal.berakhir), sidik $sidik"

Write-Host ''
Write-Host '  SIAP. Peserta membuka ujian lewat ikon di desktop:' -ForegroundColor Green
Write-Host "    $nama" -ForegroundColor Green
Write-Host '  Keluar dari SEB membutuhkan sandi dari pengawas.' -ForegroundColor Gray
Selesai 0
