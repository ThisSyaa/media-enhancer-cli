@echo off
setlocal enabledelayedexpansion
title AI Video & Foto Enhancer

:: ─── SELALU JALANKAN DARI FOLDER SCRIPT ────────────
cd /d "%~dp0"

cls
echo =================================================
echo    SISTEM AI VIDEO ^& FOTO ENHANCER TERMINAL
echo =================================================
echo.
echo [ MEMERIKSA ^& MENYIAPKAN SISTEM... ]
echo.
echo     Lokasi: %~dp0
echo.

:: ─── CEK PYTHON ────────────────────────────────────
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python tidak ditemukan!
    echo Instal Python 3.10+ dari: https://www.python.org/downloads/
    echo Pastikan centang "Add Python to PATH" saat instalasi.
    echo.
    pause
    exit /b 1
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo [OK] Python %PY_VER% terdeteksi.

:: ─── CEK FFMPEG ────────────────────────────────────
where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo [!] FFmpeg tidak ditemukan. Mencoba install via winget...
    winget install --id Gyan.FFmpeg -e --silent 2>nul
    where ffmpeg >nul 2>&1
    if errorlevel 1 (
        where choco >nul 2>&1
        if not errorlevel 1 choco install ffmpeg -y >nul 2>&1
    )
    where ffmpeg >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] FFmpeg tidak bisa diinstal otomatis.
        echo Unduh dari: https://ffmpeg.org/download.html
        echo Tambahkan folder bin-nya ke System PATH lalu jalankan ulang.
        echo.
        pause
        exit /b 1
    )
    echo [OK] FFmpeg berhasil diinstal.
) else (
    echo [OK] FFmpeg terdeteksi.
)

:: ─── SETUP VIRTUAL ENVIRONMENT ─────────────────────
if exist venv\ (
    if not exist venv\Scripts\activate.bat (
        echo [!] Folder venv tidak valid. Menghapus dan membuat ulang...
        rmdir /s /q venv
    )
)

if not exist venv\ (
    echo [->] Membuat virtual environment Python...
    python -m venv venv 2>nul
    if not exist venv\Scripts\activate.bat (
        echo [ERROR] Gagal membuat virtual environment.
        echo Pastikan Python diinstal dari https://www.python.org/downloads/
        echo.
        pause
        exit /b 1
    )
    echo [OK] Virtual environment dibuat.
) else (
    echo [OK] Virtual environment sudah ada.
)

call venv\Scripts\activate.bat
if errorlevel 1 (
    echo [ERROR] Gagal mengaktifkan virtual environment.
    echo Hapus folder venv lalu jalankan ulang.
    pause
    exit /b 1
)

:: ─── INSTALL DEPENDENSI PYTHON (ringan, tanpa torch/basicsr) ─
python -c "from PIL import Image" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [->] Menginstal Pillow ^(sekali saja^)...
    pip install Pillow -q
    echo [OK] Pillow terinstal.
) else (
    echo [OK] Dependensi Python sudah lengkap.
)

:: ─── BUAT FOLDER KERJA ─────────────────────────────
if not exist input_foto  mkdir input_foto
if not exist input_video mkdir input_video
if not exist output_hasil mkdir output_hasil
echo [OK] Folder kerja siap.

echo.
echo [ SISTEM SIAP ]
echo [i] Binary AI akan diunduh otomatis saat pertama kali memproses.
echo =================================================
echo.

:: ─── MENU UTAMA (LOOP) ──────────────────────────────
:menu
cls
echo =================================================
echo    SISTEM AI VIDEO ^& FOTO ENHANCER TERMINAL
echo =================================================
echo.
echo Pilih Tipe Media:
echo   1^) Foto / Gambar
echo   2^) Video
echo   0^) Keluar
echo.
set MEDIA_CHOICE=
set /p MEDIA_CHOICE=Masukkan pilihan (0-2): 

if "!MEDIA_CHOICE!"=="0" goto :keluar
if "!MEDIA_CHOICE!"=="" goto :menu
if not "!MEDIA_CHOICE!"=="1" if not "!MEDIA_CHOICE!"=="2" (
    echo [!] Pilihan tidak valid.
    goto :menu
)

echo.
echo Pilih Skala Upscaling:
echo   1^) 2x ^(Lebih Cepat^)
echo   2^) 4x ^(Ultra HD^)
echo.
set SCALE_CHOICE=
set /p SCALE_CHOICE=Masukkan pilihan (1-2): 
set SCALE=2
if "!SCALE_CHOICE!"=="2" set SCALE=4

echo.
echo Pilih Mode Enhancement:
echo   1^) Standard ^(AI Upscaling saja^)
echo   2^) Premium ^(AI + Sharpening^)
echo.
set DETAIL_CHOICE=
set /p DETAIL_CHOICE=Masukkan pilihan (1-2): 
set MODE=standard
if "!DETAIL_CHOICE!"=="2" set MODE=premium

echo.
echo Pengaturan: Skala !SCALE!x, Mode !MODE!
echo.

:: ─── PROSES FOTO ───────────────────────────────────
if "!MEDIA_CHOICE!"=="1" (
    echo === MEMULAI AI IMAGE UPSCALING ===
    set COUNT=0
    for %%f in (input_foto\*.jpg input_foto\*.jpeg input_foto\*.png input_foto\*.webp) do (
        set /a COUNT+=1
        echo.
        echo [!COUNT!] Processing: %%~nxf
        python "%~dp0ai_engine.py" "%%f" "output_hasil\%%~nf_enhanced_x!SCALE!.png" !SCALE! !MODE!
    )
    if !COUNT!==0 (
        echo.
        echo [!] Tidak ada file gambar di folder input_foto.
        echo     Taruh file .jpg/.png/.webp ke sana lalu jalankan ulang.
    ) else (
        echo.
        echo [OK] !COUNT! foto selesai diproses. Hasil ada di folder output_hasil.
    )
    goto :tanya_lagi
)

:: ─── PROSES VIDEO ──────────────────────────────────
if "!MEDIA_CHOICE!"=="2" (
    echo === MEMULAI AI VIDEO UPSCALING ===
    set VID_COUNT=0
    for %%v in (input_video\*.mp4 input_video\*.mov input_video\*.mkv) do (
        set /a VID_COUNT+=1
        echo ----------------------------------------
        echo Video !VID_COUNT!: %%~nxv
        if exist temp_video_frames rmdir /s /q temp_video_frames
        mkdir temp_video_frames

        echo [1/3] Mengekstrak frame...
        ffmpeg -i "%%v" -q:v 2 "temp_video_frames\frame_%%04d.png" 2>nul

        echo.
        echo [2/3] Upscaling setiap frame via AI...
        set FRAME_COUNT=0
        for %%g in (temp_video_frames\frame_*.png) do (
            set /a FRAME_COUNT+=1
            echo     Frame !FRAME_COUNT!: %%~nxg
            python "%~dp0ai_engine.py" "%%g" "temp_video_frames\enhanced_%%~nxg" !SCALE! !MODE!
        )

        echo.
        echo [3/3] Mendeteksi FPS dan merakit ulang video + audio...
        for /f "tokens=*" %%r in ('ffprobe -v error -select_streams v:0 -show_entries stream^=r_frame_rate -of default^=noprint_wrappers^=1:nokey^=1 "%%v" 2^>nul') do set RAW_FPS=%%r
        for /f %%c in ('python -c "r=\"!RAW_FPS!\"; n,d=map(int,r.split('/')) if '/' in r else (int(r),1); print(round(n/d,3))" 2^>nul') do set FPS=%%c
        if "!FPS!"=="" set FPS=30
        echo     FPS terdeteksi: !FPS!

        ffmpeg -y -r !FPS! ^
            -i "temp_video_frames\enhanced_frame_%%04d.png" ^
            -i "%%v" ^
            -map 0:v -map 1:a? ^
            -c:v libx264 -pix_fmt yuv420p -c:a copy ^
            "output_hasil\%%~nv_enhanced_x!SCALE!.mp4" 2>nul

        rmdir /s /q temp_video_frames
        echo [OK] Selesai: %%~nv_enhanced_x!SCALE!.mp4
    )
    if !VID_COUNT!==0 (
        echo.
        echo [!] Tidak ada file video di folder input_video.
        echo     Taruh file .mp4/.mov/.mkv ke sana lalu jalankan ulang.
    ) else (
        echo.
        echo [OK] !VID_COUNT! video selesai diproses. Hasil ada di folder output_hasil.
    )
    goto :tanya_lagi
)

:: ─── SELESAI: TANYA MAU PROSES LAGI? ───────────────
:tanya_lagi
echo.
echo -------------------------------------------------
echo Mau memproses file lain?
echo   1^) Ya, kembali ke menu
echo   0^) Tidak, keluar
echo.
set LAGI=
set /p LAGI=Pilihan (0-1): 
if "!LAGI!"=="1" goto :menu
if "!LAGI!"=="" goto :menu

:keluar
echo.
echo Terima kasih. Program ditutup.
echo.
endlocal