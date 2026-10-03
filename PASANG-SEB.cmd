@echo off
rem Pasang Safe Exam Browser + konfigurasi ujian CBT BQAM.
rem Klik dua kali berkas ini. Windows akan meminta izin Administrator.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pasang-seb.ps1" %*
