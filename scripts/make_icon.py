#!/usr/bin/env python3
"""1024 app icon: cream stylized 'R' with warm sage node on charcoal. Python stdlib only."""
import struct
import zlib
from pathlib import Path

W = 1024
BG = (11, 12, 14)       # Charcoal canvas
FG = (232, 226, 214)     # Warm cream
ACCENT = (126, 168, 146) # Sage green accent node


def point_line_distance(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
    dx = x2 - x1
    dy = y2 - y1
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return ((px - x1) ** 2 + (py - y1) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / length_sq))
    proj_x = x1 + t * dx
    proj_y = y1 + t * dy
    return ((px - proj_x) ** 2 + (py - proj_y) ** 2) ** 0.5


def pixel(x: int, y: int) -> tuple[int, int, int]:
    # Vertical stem of 'R'
    if 310 <= x <= 390 and 270 <= y <= 754:
        return FG

    # Upper loop of 'R': semicircle / arc centered at (390, 395)
    dx = x - 390
    dy = y - 395
    dist = (dx * dx + dy * dy) ** 0.5
    if dx >= 0 and 125 * 0.4 <= dist <= 125 and 270 <= y <= 520:
        return FG

    # Horizontal top bar
    if 310 <= x <= 390 and 270 <= y <= 350:
        return FG

    # Horizontal mid bar
    if 310 <= x <= 390 and 440 <= y <= 520:
        return FG

    # Diagonal leg of 'R': line segment from (370, 480) to (630, 750)
    leg_dist = point_line_distance(x, y, 370, 480, 630, 750)
    if leg_dist <= 40 and 460 <= y <= 754:
        return FG

    # Accent node: LLM spark / beacon circle at (640, 350) radius 38
    adx = x - 640
    ady = y - 350
    a_dist = (adx * adx + ady * ady) ** 0.5
    if a_dist <= 38:
        return ACCENT

    return BG


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def main() -> None:
    raw = bytearray()
    for y in range(W):
        raw.append(0)  # filter type 0 (None)
        for x in range(W):
            raw.extend(pixel(x, y))

    ihdr = struct.pack(">IIBBBBB", W, W, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )

    out = (
        Path(__file__).resolve().parents[1]
        / "RakuLLM"
        / "Resources"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
        / "AppIcon.png"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    print(f"wrote {out} ({len(png)} bytes)")


if __name__ == "__main__":
    main()
