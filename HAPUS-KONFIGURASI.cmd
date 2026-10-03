@echo off
rem Hapus konfigurasi ujian CBT BQAM dari PC ini sekarang juga (SEB tetap terpasang).
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pasang-seb.ps1" -Hapus
