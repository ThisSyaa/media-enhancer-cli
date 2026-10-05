"""
ai_engine.py — wrapper Real-ESRGAN NCNN Vulkan (portable binary)
Tidak butuh torch, basicsr, CUDA, atau compiler apapun.
Binary + model didownload otomatis saat pertama kali dijalankan.
"""

import os
import sys
import subprocess
import platform
import zipfile
import tarfile
import shutil
import urllib.request

# ── Konfigurasi ────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BIN_DIR    = os.path.join(SCRIPT_DIR, "realesrgan-bin")

# ZIP PORTABLE LENGKAP dari xinntao/Real-ESRGAN v0.2.5.0
# Sudah include binary + semua model (realesrgan-x4plus, realesrnet-x4plus, dll)
PORTABLE_URL = {
    "windows": "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip",
    "darwin":  "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip",
    "linux":   "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip",
}

PORTABLE_NAME = {
    "windows": "realesrgan-ncnn-vulkan-20220424-windows.zip",
    "darwin":  "realesrgan-ncnn-vulkan-20220424-macos.zip",
    "linux":   "realesrgan-ncnn-vulkan-20220424-ubuntu.zip",
}

PLATFORM_EXE = {
    "windows": "realesrgan-ncnn-vulkan.exe",
    "darwin":  "realesrgan-ncnn-vulkan",
    "linux":   "realesrgan-ncnn-vulkan",
}

MODEL_MAP = {
    2: "realesrgan-x4plus",
    4: "realesrgan-x4plus",
}

# ── Deteksi OS ────────────────────────────────────────────────
def get_os():
    s = platform.system().lower()
    if s == "windows": return "windows"
    if s == "darwin":  return "darwin"
    return "linux"


# ── Download dengan progress bar ──────────────────────────────
def download_with_progress(url, dest):
    def reporthook(count, block_size, total_size):
        if total_size <= 0:
            return
        pct = min(int(count * block_size * 100 / total_size), 100)
        bar = "#" * (pct // 5) + "-" * (20 - pct // 5)
        print(f"\r  [{bar}] {pct}%", end="", flush=True)
    urllib.request.urlretrieve(url, dest, reporthook)
    print()


# ── Cari exe di dalam folder (rekursif) ──────────────────────
def find_exe(search_dir, exe_name):
    for root, dirs, files in os.walk(search_dir):
        if exe_name in files:
            return os.path.join(root, exe_name)
    return None


# ── Pastikan binary + model tersedia ─────────────────────────
def ensure_binary(os_name):
    exe_name = PLATFORM_EXE[os_name]

    # Cek apakah exe sudah ada
    exe_path = find_exe(BIN_DIR, exe_name) if os.path.isdir(BIN_DIR) else None

    if not exe_path:
        print("  [->] Binary Real-ESRGAN belum ada. Mengunduh sekarang...")
        print("       (hanya perlu download sekali, ukuran ~30 MB, sudah include model)")

        os.makedirs(BIN_DIR, exist_ok=True)
        url          = PORTABLE_URL[os_name]
        archive_name = PORTABLE_NAME[os_name]
        archive_dest = os.path.join(BIN_DIR, archive_name)

        print(f"  [->] Mengunduh {archive_name}...")
        try:
            download_with_progress(url, archive_dest)
        except Exception as e:
            print(f"\n  [ERROR] Gagal download: {e}")
            print(f"          Download manual dari:\n          {url}")
            print(f"          Ekstrak ke folder: {BIN_DIR}")
            sys.exit(1)

        print("  [->] Mengekstrak...")
        if archive_dest.endswith(".zip"):
            with zipfile.ZipFile(archive_dest, "r") as z:
                z.extractall(BIN_DIR)
        elif archive_dest.endswith(".tar.gz"):
            with tarfile.open(archive_dest, "r:gz") as t:
                t.extractall(BIN_DIR)
        os.remove(archive_dest)

        exe_path = find_exe(BIN_DIR, exe_name)
        if not exe_path:
            print(f"  [ERROR] Executable '{exe_name}' tidak ditemukan setelah ekstrak.")
            sys.exit(1)

        if os_name != "windows":
            os.chmod(exe_path, 0o755)

    # models/ harus ada di folder yang sama dengan exe
    exe_dir    = os.path.dirname(os.path.abspath(exe_path))
    models_dir = os.path.join(exe_dir, "models")
    if not os.path.isdir(models_dir):
        print(f"  [ERROR] Folder models/ tidak ditemukan di {exe_dir}")
        print(f"          Coba hapus folder realesrgan-bin dan jalankan ulang.")
        sys.exit(1)

    return exe_path, models_dir


# ── Proses upscaling ──────────────────────────────────────────
def upscale(input_path, output_path, scale, mode, os_name):
    exe_path, models_dir = ensure_binary(os_name)

    ncnn_scale = 4
    model      = MODEL_MAP[scale]

    cmd = [
        os.path.abspath(exe_path),
        "-i", os.path.abspath(input_path),
        "-o", os.path.abspath(output_path),
        "-n", model,
        "-m", os.path.abspath(models_dir),
        "-s", str(ncnn_scale),
        "-f", "png",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  [ERROR] realesrgan-ncnn-vulkan: {result.stderr.strip()}")
        sys.exit(1)

    # Jika user minta 2x, resize hasil 4x menjadi 2x
    if scale == 2:
        try:
            from PIL import Image
            img = Image.open(output_path)
            w, h = img.size
            img  = img.resize((w // 2, h // 2), Image.LANCZOS)
            img.save(output_path)
        except ImportError:
            try:
                import cv2
                img = cv2.imread(output_path)
                h, w = img.shape[:2]
                img  = cv2.resize(img, (w // 2, h // 2), interpolation=cv2.INTER_LANCZOS4)
                cv2.imwrite(output_path, img)
            except ImportError:
                pass

    # Mode Premium: tambah sharpening
    if mode == "premium":
        try:
            from PIL import Image, ImageFilter, ImageEnhance
            img = Image.open(output_path)
            img = img.filter(ImageFilter.SHARPEN)
            img = ImageEnhance.Sharpness(img).enhance(1.5)
            img.save(output_path)
        except ImportError:
            pass


# ── Pastikan PIL tersedia ─────────────────────────────────────
def ensure_pil():
    try:
        from PIL import Image  # noqa
    except ImportError:
        print("  [->] Menginstal Pillow...")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "Pillow", "-q"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )


# ── Main ──────────────────────────────────────────────────────
def main():
    if len(sys.argv) < 5:
        print("Usage: python ai_engine.py <input> <output> <scale> <mode>")
        sys.exit(1)

    input_path  = sys.argv[1]
    output_path = sys.argv[2]
    scale       = int(sys.argv[3])
    mode        = sys.argv[4]

    os_name = get_os()
    print(f"  OS: {platform.system()} | Mode: {mode} | Skala: {scale}x")

    ensure_pil()

    out_dir = os.path.dirname(output_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    upscale(input_path, output_path, scale, mode, os_name)
    print(f"  [OK] Sukses: {output_path}")


if __name__ == "__main__":
    main()