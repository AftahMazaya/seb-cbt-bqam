#!/usr/bin/env python3
"""
Pembuat berkas konfigurasi Safe Exam Browser (.seb) untuk CBT BQAM.

    python3 buat-seb.py                      # tanya sandi keluar, tulis repo/cbt-bqam.seb
    python3 buat-seb.py --sandi-acak         # buat sandi keluar acak dan tampilkan sekali
    python3 buat-seb.py --berakhir "2026-10-20 15:00"   # sekaligus perbarui jadwal hapus

Yang diatur, dan alasannya:
  * Layar: maksimal 1 layar, layar eksternal DIIZINKAN, dan kegagalan membaca
    data layar tidak menghentikan ujian. Monitor PC selalu terbaca "eksternal",
    jadi aturan "layar bawaan saja" atau galat WMI di PC lama adalah penyebab
    pesan "Prohibited Display Configuration" di PC berlayar tunggal.
  * Alamat awal: halaman login Moodle. Satu berkas .seb dipakai untuk semua
    kuis, sehingga kuis di Moodle diatur "Gunakan konfigurasi klien SEB"
    (atau SEB tidak diwajibkan sama sekali, lihat README).
  * Saring alamat: hanya cbt. dan token-cbt.perpustakaanbqam.com yang bisa
    dibuka sebagai halaman. Gambar/skrip pendukung (MathJax, Cloudflare) tidak
    disaring supaya soal tetap tampil lengkap.
  * Keluar SEB butuh sandi pengawas. Yang disimpan di berkas hanya SHA-256-nya.
    Berkas ini akan publik di GitHub, jadi sandi harus panjang dan acak.

Format berkas: gzip( "plnd" + gzip( XML plist ) ) — blok data polos SEB,
tanpa enkripsi, sehingga peserta cukup klik dua kali tanpa mengetik sandi.
"""
import argparse
import getpass
import gzip
import hashlib
import json
import os
import secrets
import sys
from datetime import datetime, timedelta, timezone
from xml.sax.saxutils import escape

DIR = os.path.dirname(os.path.abspath(__file__))
# Di dalam repo GitHub skrip ini berdampingan dengan cbt-bqam.seb;
# di folder kerja panitia, hasilnya ditaruh di subfolder repo/.
REPO = os.path.join(DIR, "repo") if os.path.isdir(os.path.join(DIR, "repo")) else DIR
WIB = timezone(timedelta(hours=7))

MOODLE = "https://cbt.perpustakaanbqam.com"
HOST_BOLEH = ["cbt.perpustakaanbqam.com", "token-cbt.perpustakaanbqam.com"]


def plist(nilai, tingkat=1):
    """Nilai Python -> XML plist (bool, int, str, list, dict)."""
    t = "\t" * tingkat
    if isinstance(nilai, bool):
        return "<true/>" if nilai else "<false/>"
    if isinstance(nilai, int):
        return f"<integer>{nilai}</integer>"
    if isinstance(nilai, str):
        return f"<string>{escape(nilai)}</string>"
    if isinstance(nilai, list):
        if not nilai:
            return "<array/>"
        isi = "".join(f"\n{t}\t{plist(v, tingkat + 1)}" for v in nilai)
        return f"<array>{isi}\n{t}</array>"
    if isinstance(nilai, dict):
        isi = "".join(f"\n{t}\t<key>{escape(k)}</key>\n{t}\t{plist(nilai[k], tingkat + 1)}" for k in sorted(nilai))
        return f"<dict>{isi}\n{t}</dict>"
    raise TypeError(type(nilai))


def setelan(hash_keluar: str) -> dict:
    aturan = [{"active": True, "regex": False, "expression": h, "action": 1} for h in HOST_BOLEH]
    return {
        "originatorVersion": "SEB_Win_3.10.2",
        "sebConfigPurpose": 0,                     # memulai ujian
        "startURL": MOODLE + "/login/index.php",
        "startURLAppendQueryParameter": False,

        # --- keluar ---
        "allowQuit": True,
        "hashedQuitPassword": hash_keluar,
        "quitURL": "",
        "quitURLConfirm": True,

        # --- layar: penyebab "Prohibited Display Configuration" ---
        "allowedDisplaysMaxNumber": 1,
        "allowedDisplayBuiltin": False,            # (macOS) jangan paksa layar bawaan
        "allowedDisplayBuiltinEnforce": False,     # Windows: InternalDisplayOnly
        "allowedDisplayBuiltinExceptDesktop": True,
        "allowedDisplaysIgnoreFailure": True,      # PC lama yang WMI-nya tidak menjawab
        "allowDisplayMirroring": False,
        "displayAlwaysOn": True,

        # --- tampilan browser ---
        "browserViewMode": 1,                      # layar penuh
        "enableBrowserWindowToolbar": False,
        "browserWindowAllowAddressBar": False,
        "browserWindowShowURL": 0,
        "showReloadButton": True,
        "browserWindowAllowReload": True,
        "showReloadWarning": True,
        "newBrowserWindowAllowReload": True,
        "allowBrowsingBackForward": False,
        "enableZoomPage": True,
        "enableZoomText": True,
        "allowFind": False,
        "allowSpellCheck": False,
        "allowPrint": False,
        "allowDownloads": False,
        "allowUploads": False,
        "downloadAndOpenSebConfig": False,         # tidak boleh memuat .seb lain dari web
        "allowDeveloperConsole": False,
        "allowPDFReaderToolbar": False,
        "newBrowserWindowByLinkPolicy": 2,
        "newBrowserWindowByLinkBlockForeign": True,
        "sendBrowserExamKey": True,

        # --- sesi bersih tiap kali dibuka ---
        "examSessionClearCookiesOnStart": True,
        "examSessionClearCookiesOnEnd": True,
        "removeBrowserProfile": True,
        "examSessionReconfigureAllow": False,

        # --- saring alamat ---
        "URLFilterEnable": True,
        "URLFilterEnableContentFilter": False,
        "URLFilterRules": aturan,

        # --- penguncian Windows ---
        "createNewDesktop": True,
        "killExplorerShell": False,
        "allowVirtualMachine": False,
        "allowScreenSharing": False,
        "allowApplicationLog": False,
        "enableRightMouse": False,
        "enablePrintScreen": False,
        "enableAltTab": False,
        "enableAltF4": False,
        "enableCtrlEsc": False,
        "enableEsc": True,
        "enableStartMenu": False,
        "enableF1": False, "enableF3": False, "enableF4": False, "enableF7": False,
        "enableF8": False, "enableF9": False, "enableF10": False, "enableF11": False,
        "enableF12": False,
        "enableF5": True,                          # muat ulang halaman bila tersendat

        # --- bilah tugas SEB ---
        "showTaskBar": True,
        "showTime": True,
        "showInputLanguage": False,
        "allowWlan": True,                         # laptop yang memakai Wi-Fi
        "audioControlEnabled": True,
        "audioMute": False,
        "allowAudioCapture": False,
        "allowVideoCapture": False,
    }


def bungkus(xml: str) -> bytes:
    dalam = gzip.compress(xml.encode("utf-8"), mtime=0)
    return gzip.compress(b"plnd" + dalam, mtime=0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sandi-acak", action="store_true", help="buat sandi keluar acak")
    ap.add_argument("--berakhir", help='jadwal hapus otomatis, WIB, mis. "2026-10-20 15:00"')
    ap.add_argument("--keluar", default=os.path.join(REPO, "cbt-bqam.seb"))
    a = ap.parse_args()

    if a.sandi_acak:
        abjad = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
        sandi = "-".join("".join(secrets.choice(abjad) for _ in range(4)) for _ in range(4))
    else:
        sandi = getpass.getpass("Sandi keluar SEB (min. 12 karakter): ")
        if len(sandi) < 12:
            sys.exit("Terlalu pendek. Berkas ini publik; sandi pendek bisa ditebak dari hash-nya.")
        if getpass.getpass("Ulangi: ") != sandi:
            sys.exit("Sandi tidak sama.")
    h = hashlib.sha256(sandi.encode("utf-8")).hexdigest()

    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
           '<plist version="1.0">\n' + plist(setelan(h), 0) + "\n</plist>\n")
    data = bungkus(xml)
    os.makedirs(os.path.dirname(a.keluar), exist_ok=True)
    with open(a.keluar, "wb") as f:
        f.write(data)
    sidik = hashlib.sha256(data).hexdigest()

    # jadwal.json: dibaca skrip pemasang di tiap PC
    jp = os.path.join(os.path.dirname(a.keluar), "jadwal.json")
    j = {}
    if os.path.exists(jp):
        with open(jp, encoding="utf-8") as f:
            j = json.load(f)
    if a.berakhir:
        t = datetime.strptime(a.berakhir, "%Y-%m-%d %H:%M").replace(tzinfo=WIB)
        j["berakhir"] = t.isoformat()
    j.setdefault("berakhir", (datetime.now(WIB) + timedelta(days=7)).replace(hour=17, minute=0, second=0, microsecond=0).isoformat())
    j["berkas"] = os.path.basename(a.keluar)
    j["sha256"] = sidik
    j["nama_pintasan"] = j.get("nama_pintasan", "Ujian CBT BQAM")
    j["diperbarui"] = datetime.now(WIB).replace(microsecond=0).isoformat()
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(j, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Tertulis : {a.keluar} ({len(data)} byte)")
    print(f"SHA-256  : {sidik}")
    print(f"Hapus    : {j['berakhir']}  (jadwal.json)")
    if a.sandi_acak:
        print(f"\nSANDI KELUAR SEB: {sandi}\nCatat sekarang dan bagikan hanya ke pengawas. Tidak ditampilkan lagi.")


if __name__ == "__main__":
    main()
