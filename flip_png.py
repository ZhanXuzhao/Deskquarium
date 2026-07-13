"""
水平翻转 PNG 图片脚本
用法: python flip_png.py <图片路径>
      python flip_png.py <图片路径> -o output.png
      python flip_png.py <文件夹路径>  # 批量翻转文件夹内所有 PNG
"""

import sys
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("请先安装 Pillow: pip install Pillow")
    sys.exit(1)


def flip_image(input_path: Path, output_path: Path | None = None) -> None:
    """水平翻转一张 PNG 图片"""
    img = Image.open(input_path)
    flipped = img.transpose(Image.FLIP_LEFT_RIGHT)

    if output_path is None:
        stem = input_path.stem
        output_path = input_path.with_stem(f"{stem}_flipped")

    flipped.save(output_path, "PNG")
    print(f"已翻转: {input_path.name} -> {output_path.name}")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)

    target = Path(args[0])
    output = Path(args[2]) if len(args) >= 3 and args[1] == "-o" else None

    if target.is_file():
        flip_image(target, output)
    elif target.is_dir():
        for png in target.glob("*.png"):
            flip_image(png)
    else:
        print(f"路径不存在: {target}")
        sys.exit(1)


if __name__ == "__main__":
    main()
