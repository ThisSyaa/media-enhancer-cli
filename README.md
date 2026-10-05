# Sistem AI Video & Foto Enhancement (CLI)

Sistem otomatis berbasis terminal untuk melakukan **AI Upscaling** pada foto dan video menggunakan **Real-ESRGAN** dan **FFmpeg**.

---

## Persyaratan Sistem

- Python 3.10+
- FFmpeg
- (Opsional) GPU NVIDIA dengan CUDA untuk kecepatan optimal

---

## Instalasi

### 1. Instal FFmpeg

- **Linux (Ubuntu/Debian):**
  ```bash
  sudo apt update && sudo apt install -y ffmpeg
  ```
- **macOS:**
  ```bash
  brew install ffmpeg
  ```
- **Windows:** Download dari https://ffmpeg.org/download.html, lalu tambahkan ke PATH.

### 2. Buat Virtual Environment & Instal Dependensi Python

```bash
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# Jika pakai GPU NVIDIA (CUDA 11.8):
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# Jika CPU only:
pip install torch torchvision

# Instal AI engine & dependensi lain:
pip install -r requirements.txt
```

---

## Struktur Direktori

```
media-enhancer-cli/
├── input_foto/          ← Taruh foto di sini (.jpg, .png, .webp)
├── input_video/         ← Taruh video di sini (.mp4, .mov, .mkv)
├── output_hasil/        ← Hasil akhir tersimpan di sini
├── ai_engine.py         ← Core AI Engine (Python)
├── enhancer.sh          ← Skrip otomatisasi (Linux/macOS)
├── enhancer.bat         ← Skrip otomatisasi (Windows)
└── requirements.txt     ← Daftar dependensi Python
```

---

## Cara Menjalankan

### Linux / macOS

```bash
chmod +x enhancer.sh
./enhancer.sh
```

### Windows

Klik dua kali `enhancer.bat` atau jalankan di Command Prompt:

```cmd
enhancer.bat
```

---

## Menu Pilihan Interaktif

Saat skrip dijalankan, Anda akan diminta memilih:

1. **Tipe Media:** Foto atau Video
2. **Skala Upscaling:**
   - `2x` — Perbaikan ringan, proses lebih cepat
   - `4x` — Resolusi Ultra HD, hasil maksimal
3. **Mode Enhancement:**
   - `Standard` — Hanya AI Upscaling
   - `Premium Detail` — AI Upscaling + Noise Reduction + Sharpening

---

## Catatan Teknis

- **Video Processing:** Video dipecah menjadi frame → setiap frame di-upscale → frame digabung kembali + audio asli ditempel.
- **FPS:** Script otomatis mendeteksi FPS dari video asli (Linux/macOS). Windows menggunakan default 30 FPS.
- **Temp Files:** File sementara (`temp_video_frames/`) otomatis dihapus setelah proses selesai.

---

## Contoh Output

| Input | Output |
|-------|--------|
| `foto_blur.jpg` (720p) | `foto_blur_enhanced_x4.png` (2880p) |
| `video_low.mp4` (480p) | `video_low_enhanced_x4.mp4` (1920p) |
