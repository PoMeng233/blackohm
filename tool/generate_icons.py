"""生成 BlackOhm 的 UI 位图、Windows / 托盘 ICO，以及 README 展示图。

两个矢量源，用途分离：

* assets/icon.svg          —— 透明背景的小屋标记，**实际图标唯一来源**：
                              UI 展示图、windows/runner/resources/app_icon.ico、assets/tray.ico
* docs/icon-showcase.svg   —— 圆角磨砂玻璃底座版，仅用于 README 展示，不参与打包

替换旧脚本 tool/generate_app_icons.py：旧实现把 139x137 的位图源 `thumbnail`
后居中塞进 256 画布（thumbnail 不会放大），导致 ICO 内容只占画布约一半，
图标在任务栏里明显比其它应用小。本脚本按每档目标尺寸原生渲染，图案满幅。

依赖：Pillow；渲染用本机 Chrome / Edge 的 headless 截图（Windows 自带 Edge）。

用法：
    python tool/generate_icons.py            # 生成全部图标与展示图
    python tool/generate_icons.py --preview  # 额外输出多尺寸对照图便于目检
"""
from __future__ import annotations

import argparse
import io
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MARK_SVG = ROOT / "assets" / "icon.svg"
SHOWCASE_SVG = ROOT / "docs" / "icon-showcase.svg"

# UI 里 Image.asset 引用的路径保持 icon_source.png，避免为改名去动 UI 代码。
UI_PNG = ROOT / "assets" / "icon_source.png"
TRAY_ICO = ROOT / "assets" / "tray.ico"
APP_ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
SHOWCASE_PNG = ROOT / "docs" / "icon-showcase.png"
PREVIEW_PNG = ROOT / "docs" / "icon-preview.png"

# 托盘 16px 起就要清晰；exe 图标额外包含 128/256 供任务栏与开始菜单大图使用。
TRAY_SIZES = (16, 20, 24, 32, 40, 48, 64)
APP_SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)
UI_SIZE = 512
SHOWCASE_SIZE = 512

BROWSERS = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
)


def find_browser() -> str:
    for path in BROWSERS:
        if Path(path).exists():
            return path
    raise FileNotFoundError(
        "未找到 Chrome / Edge，无法渲染 SVG。请安装其中之一后重试。"
    )


def _sized_svg(source: Path, size: int) -> str:
    """注入显式宽高：viewBox 保证构图不变，宽高决定光栅尺寸。"""
    raw = source.read_text(encoding="utf-8")
    raw = re.sub(r'width="100%" height="100%"', "", raw, count=1)
    return raw.replace("<svg ", f'<svg width="{size}" height="{size}" ', 1)


def render_png(source: Path, size: int, browser: str) -> Image.Image:
    """按目标尺寸原生渲染，避免大图缩放带来的边缘发虚。"""
    with tempfile.TemporaryDirectory() as td:
        svg_path = Path(td) / "icon.svg"
        png_path = Path(td) / "icon.png"
        svg_path.write_text(_sized_svg(source, size), encoding="utf-8")
        subprocess.run(
            [
                browser,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--screenshot={png_path}",
                f"--window-size={size},{size}",
                svg_path.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        image = Image.open(png_path).convert("RGBA")
    if image.size != (size, size):
        image = image.resize((size, size), Image.LANCZOS)
    return image


def _png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def write_ico(target: Path, sizes: tuple[int, ...], browser: str) -> None:
    """把每档尺寸的原生渲染写入 ICO。

    Pillow 的 ICO 保存只接受一张图再自行缩放，无法用上各尺寸的原生渲染，
    因此这里手写 ICO 容器：PNG 载荷（Windows Vista 起支持，Win10/11 的
    托盘与资源管理器均可正常读取）。
    """
    entries = b""
    payloads = b""
    offset = 6 + 16 * len(sizes)
    for size in sizes:
        blob = _png_bytes(render_png(MARK_SVG, size, browser))
        dim = 0 if size >= 256 else size  # 256 在 ICO 目录里记 0
        entries += struct.pack(
            "<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset
        )
        offset += len(blob)
        payloads += blob
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(struct.pack("<HHH", 0, 1, len(sizes)) + entries + payloads)


def build_preview(browser: str) -> None:
    """浅色/深色双背景 + 大图与各档实际尺寸，便于目检托盘可读性。"""
    sizes = (64, 48, 32, 24, 16)
    width, height = 480, 355
    sheet = Image.new("RGBA", (width, height), (245, 245, 245, 255))
    for y in range(height):
        for x in range(width // 2, width):
            sheet.putpixel((x, y), (32, 32, 32, 255))
    sheet.alpha_composite(render_png(MARK_SVG, 256, browser), ((width - 256) // 2, 6))
    row_y = 276
    x = 4
    for size in sizes:  # 浅色底
        sheet.alpha_composite(render_png(MARK_SVG, size, browser), (x, row_y))
        x += size + 12
    x = width // 2 + 4
    for size in sizes:  # 深色底
        sheet.alpha_composite(render_png(MARK_SVG, size, browser), (x, row_y))
        x += size + 12
    sheet.save(PREVIEW_PNG)


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 BlackOhm 图标资源")
    parser.add_argument("--preview", action="store_true", help="额外输出对照图")
    args = parser.parse_args()

    for source in (MARK_SVG, SHOWCASE_SVG):
        if not source.exists():
            print(f"缺少矢量源文件：{source}", file=sys.stderr)
            return 1

    browser = find_browser()
    render_png(MARK_SVG, UI_SIZE, browser).save(UI_PNG)
    render_png(SHOWCASE_SVG, SHOWCASE_SIZE, browser).save(SHOWCASE_PNG)
    write_ico(TRAY_ICO, TRAY_SIZES, browser)
    write_ico(APP_ICO, APP_SIZES, browser)

    for path in (UI_PNG, SHOWCASE_PNG, TRAY_ICO, APP_ICO):
        print(f"已生成：{path.relative_to(ROOT)}  ({path.stat().st_size} 字节)")
    print(f"  托盘尺寸：{TRAY_SIZES}")
    print(f"  应用尺寸：{APP_SIZES}")

    if args.preview:
        build_preview(browser)
        print(f"已生成：{PREVIEW_PNG.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
