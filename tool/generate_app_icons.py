"""从根目录黑白小屋源图生成 BlackOhm 的 Windows 与托盘 ICO 资源。

依赖：Pillow（本机可通过 `python -m pip install Pillow` 安装）
运行：python tool/generate_app_icons.py
"""
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icon_source.png"
TARGETS = [
    ROOT / "assets" / "tray.ico",
    ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
]
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def make_square_icon(source: Image.Image, size: int) -> Image.Image:
    """等比例缩放，在透明正方形画布居中，避免图案被 ICO 边缘截断。"""
    image = ImageOps.exif_transpose(source).convert("RGBA")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - image.width) // 2, (size - image.height) // 2)
    canvas.alpha_composite(image, offset)
    return canvas


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"未找到图标源文件：{SOURCE}")

    with Image.open(SOURCE) as source:
        largest = make_square_icon(source, max(SIZES))
        for target in TARGETS:
            target.parent.mkdir(parents=True, exist_ok=True)
            largest.save(target, format="ICO", sizes=[(size, size) for size in SIZES])
            print(f"已生成：{target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
