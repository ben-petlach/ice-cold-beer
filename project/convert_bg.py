"""
convert_bg.py  —  Convert a 160x120 monochrome PNG to a Quartus $readmemh file.

Usage:
    pip install pillow
    python convert_bg.py ice_cold_beer_monochrome.png ice_cold_beer_mono.hex

Output format (ice_cold_beer_mono.hex):
    120 lines, one per game row.
    Each line is 40 hex digits representing a 160-bit word.
    Bit[x] of word[y] = pixel at game column x, game row y.
    Bit 0 (LSB, rightmost hex digit) = game_x = 0.
    Bit 159 (MSB, leftmost hex digit) = game_x = 159.

The hex file must be placed in the Quartus project directory so that
$readmemh("ice_cold_beer_mono.hex", ...) can find it at synthesis and
simulation time.
"""

import sys
from PIL import Image


def convert(src_path: str, dst_path: str) -> None:
    img = Image.open(src_path)

    if img.size != (160, 120):
        print(f"WARNING: image is {img.size}, expected (160, 120).")
        print("Resizing with nearest-neighbour to 160x120.")
        img = img.resize((160, 120), Image.NEAREST)

    # Convert to pure 1-bit: white=1 (will appear in output), black=0 (transparent)
    img = img.convert("L")          # grayscale
    threshold = 128
    img = img.point(lambda p: 1 if p >= threshold else 0, "1")

    lines = []
    for y in range(120):
        row_val = 0
        for x in range(160):
            # getpixel on a "1"-mode image returns 0 or 255 in some Pillow
            # versions, and 0 or 1 in others — normalise to 0/1.
            px = img.getpixel((x, y))
            if px:
                row_val |= (1 << x)   # bit[x] = pixel at column x
        lines.append(f"{row_val:040x}")   # 160 bits = 40 hex digits

    with open(dst_path, "w") as f:
        f.write("\n".join(lines) + "\n")

    set_pixels = sum(bin(int(l, 16)).count("1") for l in lines)
    print(f"Written {dst_path}  ({set_pixels} / {160*120} pixels set)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_bg.py <input.png> <output.hex>")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
