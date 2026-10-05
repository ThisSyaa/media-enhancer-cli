#!/bin/bash
# =================================================
# SISTEM AI VIDEO & FOTO ENHANCER TERMINAL
# Linux / macOS Version
# =================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INPUT_FOTO="input_foto"
INPUT_VIDEO="input_video"
OUTPUT_DIR="output_hasil"
TEMP_FRAMES="temp_video_frames"

detect_os() {
    case "$(uname -s)" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="darwin" ;;
        *)       OS="linux" ;;
    esac
}

command_exists() { command -v "$1" &>/dev/null; }

install_ffmpeg() {
    echo "  → FFmpeg tidak ditemukan. Menginstal otomatis..."
    if [ "$OS" = "linux" ]; then
        if command_exists apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y ffmpeg
        elif command_exists dnf; then
            sudo dnf install -y ffmpeg
        elif command_exists pacman; then
            sudo pacman -Sy --noconfirm ffmpeg
        else
            echo "  [ERROR] Instal FFmpeg manual dari https://ffmpeg.org"
            exit 1
        fi
    elif [ "$OS" = "darwin" ]; then
        if command_exists brew; then
            brew install ffmpeg
        else
            echo "  [ERROR] Homebrew tidak ada. Instal dari https://brew.sh"
            exit 1
        fi
    fi
    echo "  ✓ FFmpeg berhasil diinstal."
}

setup_python_env() {
    echo ""
    echo "  → Memeriksa Python..."

    PYTHON_CMD=""
    if command_exists python3; then
        PYTHON_CMD="python3"
    elif command_exists python; then
        PYTHON_CMD="python"
    else
        echo "  [ERROR] Python tidak ditemukan. Instal Python 3.10+ dari https://python.org"
        exit 1
    fi

    PY_VERSION=$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    echo "  ✓ Python $PY_VERSION terdeteksi."

    if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
        echo "  [!] Folder venv tidak valid. Menghapus dan membuat ulang..."
        rm -rf venv
    fi

    if [ ! -d "venv" ]; then
        echo "  → Membuat virtual environment..."
        $PYTHON_CMD -m venv venv
        echo "  ✓ Virtual environment dibuat."
    else
        echo "  ✓ Virtual environment sudah ada."
    fi

    source venv/bin/activate

    # Hanya butuh Pillow — ringan, cepat
    if ! python -c "from PIL import Image" &>/dev/null 2>&1; then
        echo "  → Menginstal Pillow..."
        pip install Pillow -q
    fi

    echo "  ✓ Dependensi Python siap."
}

# ─── SETUP ──────────────────────────────────────────
detect_os

clear
echo "================================================="
echo "   SISTEM AI VIDEO & FOTO ENHANCER TERMINAL      "
echo "================================================="
echo ""
echo "[ MEMERIKSA & MENYIAPKAN SISTEM ]"
echo "  Lokasi: $SCRIPT_DIR"

if command_exists ffmpeg; then
    FFMPEG_VER=$(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')
    echo "  ✓ FFmpeg sudah terinstal: $FFMPEG_VER"
else
    install_ffmpeg
fi

setup_python_env

mkdir -p "$INPUT_FOTO" "$INPUT_VIDEO" "$OUTPUT_DIR"
echo "  ✓ Folder kerja siap."
echo ""
echo "[ SISTEM SIAP ]"
echo "  [i] Binary AI akan diunduh otomatis saat pertama kali memproses."
echo "================================================="

# ─── MENU ───────────────────────────────────────────
run_menu() {
    source venv/bin/activate

    clear
    echo "================================================="
    echo "   SISTEM AI VIDEO & FOTO ENHANCER TERMINAL      "
    echo "================================================="
    echo ""
    echo "Pilih Tipe Media:"
    echo "  1) Foto / Gambar"
    echo "  2) Video"
    echo "  0) Keluar"
    echo ""
    read -r -p "Masukkan pilihan (0-2): " MEDIA_CHOICE

    if [ "$MEDIA_CHOICE" = "0" ]; then
        echo ""; echo "Terima kasih. Program ditutup."; echo ""; exit 0
    fi
    if [ "$MEDIA_CHOICE" != "1" ] && [ "$MEDIA_CHOICE" != "2" ]; then
        echo "[!] Pilihan tidak valid."; return
    fi

    echo ""
    echo "Pilih Skala Upscaling:"
    echo "  1) 2x (Lebih Cepat)"
    echo "  2) 4x (Ultra HD)"
    echo ""
    read -r -p "Masukkan pilihan (1-2): " SCALE_CHOICE
    SCALE=2; [ "$SCALE_CHOICE" = "2" ] && SCALE=4

    echo ""
    echo "Pilih Mode Enhancement:"
    echo "  1) Standard (AI Upscaling saja)"
    echo "  2) Premium (AI + Sharpening)"
    echo ""
    read -r -p "Masukkan pilihan (1-2): " DETAIL_CHOICE
    MODE="standard"; [ "$DETAIL_CHOICE" = "2" ] && MODE="premium"

    echo ""
    echo "Pengaturan: Skala ${SCALE}x, Mode $MODE"
    echo ""

    # ─── PROSES FOTO ──────────────────────────────
    if [ "$MEDIA_CHOICE" = "1" ]; then
        echo "=== MEMULAI AI IMAGE UPSCALING ==="
        COUNT=0
        while IFS= read -r file; do
            filename=$(basename "$file")
            name_no_ext="${filename%.*}"
            COUNT=$((COUNT + 1))
            echo ""
            echo "[$COUNT] Processing: $filename"
            python "$SCRIPT_DIR/ai_engine.py" \
                "$file" \
                "$SCRIPT_DIR/$OUTPUT_DIR/${name_no_ext}_enhanced_x${SCALE}.png" \
                "$SCALE" "$MODE"
        done < <(find "$SCRIPT_DIR/$INPUT_FOTO" -maxdepth 1 \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            2>/dev/null | sort)

        if [ "$COUNT" -eq 0 ]; then
            echo ""; echo "[!] Tidak ada file gambar di folder '$INPUT_FOTO'."
        else
            echo ""; echo "[OK] $COUNT foto selesai. Hasil di folder '$OUTPUT_DIR'."
        fi

    # ─── PROSES VIDEO ─────────────────────────────
    elif [ "$MEDIA_CHOICE" = "2" ]; then
        echo "=== MEMULAI AI VIDEO UPSCALING ==="
        COUNT=0
        while IFS= read -r file; do
            filename=$(basename "$file")
            filename_no_ext="${filename%.*}"
            COUNT=$((COUNT + 1))

            echo "----------------------------------------"
            echo "Video $COUNT: $filename"
            rm -rf "$SCRIPT_DIR/$TEMP_FRAMES" && mkdir -p "$SCRIPT_DIR/$TEMP_FRAMES"

            echo "[1/3] Mengekstrak frame..."
            ffmpeg -i "$file" -q:v 2 "$SCRIPT_DIR/$TEMP_FRAMES/frame_%04d.png" 2>/dev/null

            FRAME_COUNT=$(find "$SCRIPT_DIR/$TEMP_FRAMES" -name "frame_*.png" 2>/dev/null | wc -l | tr -d ' ')
            echo "      Total frame: $FRAME_COUNT"

            echo "[2/3] Upscaling setiap frame via AI..."
            CURRENT=0
            while IFS= read -r frame; do
                frame_name=$(basename "$frame")
                CURRENT=$((CURRENT + 1))
                echo "      Frame $CURRENT/$FRAME_COUNT: $frame_name"
                python "$SCRIPT_DIR/ai_engine.py" \
                    "$frame" \
                    "$SCRIPT_DIR/$TEMP_FRAMES/enhanced_$frame_name" \
                    "$SCALE" "$MODE" > /dev/null 2>&1
            done < <(find "$SCRIPT_DIR/$TEMP_FRAMES" -name "frame_*.png" | sort)

            echo "[3/3] Merakit ulang video + audio..."
            fps=$(ffprobe -v error -select_streams v:0 \
                -show_entries stream=r_frame_rate \
                -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
            fps=$(python -c "r='$fps'; n,d=map(int,r.split('/')) if '/' in r else (int(r),1); print(round(n/d,3))" 2>/dev/null)
            [ -z "$fps" ] && fps=30
            echo "      FPS: $fps"

            ffmpeg -y -r "$fps" \
                -i "$SCRIPT_DIR/$TEMP_FRAMES/enhanced_frame_%04d.png" \
                -i "$file" \
                -map 0:v -map 1:a? \
                -c:v libx264 -pix_fmt yuv420p -c:a copy \
                "$SCRIPT_DIR/$OUTPUT_DIR/${filename_no_ext}_enhanced_x${SCALE}.mp4" 2>/dev/null

            rm -rf "$SCRIPT_DIR/$TEMP_FRAMES"
            echo "[OK] Selesai: ${filename_no_ext}_enhanced_x${SCALE}.mp4"
        done < <(find "$SCRIPT_DIR/$INPUT_VIDEO" -maxdepth 1 \
            \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) \
            2>/dev/null | sort)

        if [ "$COUNT" -eq 0 ]; then
            echo ""; echo "[!] Tidak ada file video di folder '$INPUT_VIDEO'."
        else
            echo ""; echo "[OK] $COUNT video selesai. Hasil di folder '$OUTPUT_DIR'."
        fi
    fi
}

# ─── LOOP UTAMA ─────────────────────────────────────
while true; do
    run_menu
    echo ""
    echo "-------------------------------------------------"
    echo "Mau memproses file lain?"
    echo "  1) Ya, kembali ke menu"
    echo "  0) Tidak, keluar"
    echo ""
    read -r -p "Pilihan (0-1): " LAGI
    [ "$LAGI" = "0" ] && { echo ""; echo "Terima kasih."; echo ""; exit 0; }
done