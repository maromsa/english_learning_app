#!/usr/bin/env python3
"""Generate illustrative PNG images for lesson words using OpenMoji icons.

This script creates 512x512 PNG assets for every word used in the lesson plan.
Whenever a matching OpenMoji glyph exists we reuse the official artwork under
its CC-BY-SA 4.0 licence. For a small set of concepts without an emoji, simple
vector illustrations are rendered with Pillow.

Running the script is idempotent and safe to repeat. All output files are
written to assets/images/words/ and overwrite existing files with the same
name.
"""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Optional

import requests
from PIL import Image, ImageDraw, ImageOps

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

ASSET_SIZE = 512
OPENMOJI_BASE = "https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618"
CACHE_DIR = Path(".cache/openmoji")
OUTPUT_DIR = Path("assets/images/words")


@dataclass(frozen=True)
class WordSpec:
    emoji_hex: Optional[str]
    background: str
    custom_renderer: Optional[Callable[[ImageDraw.ImageDraw], None]] = None


def _ensure_cache_dir() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def _fetch_openmoji(hexcode: str) -> Image.Image:
    cache_path = CACHE_DIR / f"{hexcode}.png"
    if cache_path.exists():
        return Image.open(cache_path).convert("RGBA")

    url = f"{OPENMOJI_BASE}/{hexcode}.png"
    logging.info("Downloading OpenMoji %s", hexcode)
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    cache_path.write_bytes(response.content)
    return Image.open(io.BytesIO(response.content)).convert("RGBA")


def _resize_and_center(icon: Image.Image, canvas: Image.Image, scale: float = 0.75) -> None:
    max_size = int(ASSET_SIZE * scale)
    resized = ImageOps.contain(icon, (max_size, max_size), Image.Resampling.LANCZOS)
    x = (ASSET_SIZE - resized.width) // 2
    y = (ASSET_SIZE - resized.height) // 2
    canvas.alpha_composite(resized, dest=(x, y))


def _draw_hot_air_balloon(draw: ImageDraw.ImageDraw) -> None:
    w = ASSET_SIZE
    balloon_bounds = (w * 0.18, w * 0.08, w * 0.82, w * 0.75)
    draw.ellipse(balloon_bounds, fill="#ff8a65", outline="#e64a19", width=8)

    stripe_count = 5
    left, top, right, bottom = balloon_bounds
    stripe_width = (right - left) / stripe_count
    for i in range(1, stripe_count):
        x = left + i * stripe_width
        draw.line([(x, top + 10), (x, bottom - 10)], fill="#ffffff", width=6)

    basket_width = w * 0.18
    basket_height = w * 0.1
    basket_left = (w - basket_width) / 2
    basket_top = w * 0.78
    basket_bounds = (
        basket_left,
        basket_top,
        basket_left + basket_width,
        basket_top + basket_height,
    )
    draw.rounded_rectangle(basket_bounds, radius=12, fill="#6d4c41", outline="#3e2723", width=6)

    # Ropes
    draw.line([(w * 0.4, w * 0.72), (basket_left + 12, basket_top)], fill="#4e342e", width=6)
    draw.line([(w * 0.6, w * 0.72), (basket_left + basket_width - 12, basket_top)], fill="#4e342e", width=6)


def _draw_submarine(draw: ImageDraw.ImageDraw) -> None:
    w = ASSET_SIZE
    body_bounds = (w * 0.15, w * 0.45, w * 0.85, w * 0.7)
    draw.rounded_rectangle(body_bounds, radius=60, fill="#ffeb3b", outline="#fbc02d", width=8)

    tower_bounds = (w * 0.35, w * 0.32, w * 0.5, w * 0.48)
    draw.rounded_rectangle(tower_bounds, radius=30, fill="#ffeb3b", outline="#fbc02d", width=6)

    window_radius = w * 0.05
    for idx in range(3):
        cx = w * (0.3 + idx * 0.2)
        cy = w * 0.575
        draw.ellipse((cx - window_radius, cy - window_radius, cx + window_radius, cy + window_radius),
                     fill="#81d4fa", outline="#01579b", width=6)

    prop_bounds = (w * 0.82, w * 0.5, w * 0.9, w * 0.64)
    draw.rounded_rectangle(prop_bounds, radius=30, fill="#fbc02d", outline="#f57f17", width=6)
    draw.line([(w * 0.86, w * 0.5), (w * 0.86, w * 0.64)], fill="#f57f17", width=6)

    # Periscope
    draw.rectangle((w * 0.42, w * 0.22, w * 0.46, w * 0.32), fill="#90a4ae", outline="#546e7a", width=6)
    draw.rectangle((w * 0.36, w * 0.2, w * 0.52, w * 0.24), fill="#90a4ae", outline="#546e7a", width=6)


def _draw_mars_rover(draw: ImageDraw.ImageDraw) -> None:
    w = ASSET_SIZE
    ground_height = w * 0.15
    draw.rectangle((0, w - ground_height, w, w), fill="#bf360c")

    body_bounds = (w * 0.2, w * 0.45, w * 0.8, w * 0.62)
    draw.rounded_rectangle(body_bounds, radius=30, fill="#ffcc80", outline="#e65100", width=8)

    mast_bounds = (w * 0.55, w * 0.28, w * 0.62, w * 0.45)
    draw.rectangle(mast_bounds, fill="#795548", outline="#4e342e", width=6)
    camera_bounds = (w * 0.5, w * 0.2, w * 0.67, w * 0.3)
    draw.rounded_rectangle(camera_bounds, radius=16, fill="#ffab40", outline="#e65100", width=6)
    lens_radius = w * 0.03
    lens_center = (w * 0.585, w * 0.25)
    draw.ellipse((lens_center[0] - lens_radius, lens_center[1] - lens_radius,
                  lens_center[0] + lens_radius, lens_center[1] + lens_radius),
                 fill="#263238", outline="#90caf9", width=4)

    wheel_radius = w * 0.09
    for idx in range(4):
        cx = w * (0.28 + idx * 0.16)
        cy = w * 0.64
        draw.ellipse((cx - wheel_radius, cy - wheel_radius, cx + wheel_radius, cy + wheel_radius),
                     fill="#37474f", outline="#263238", width=6)
        draw.ellipse((cx - wheel_radius * 0.5, cy - wheel_radius * 0.5,
                      cx + wheel_radius * 0.5, cy + wheel_radius * 0.5),
                     outline="#90a4ae", width=4)


WORD_SPECS: Dict[str, WordSpec] = {
    # Fruits
    "apple": WordSpec("1F34E", "#ffe0e0"),
    "banana": WordSpec("1F34C", "#fff9c4"),
    "orange": WordSpec("1F34A", "#ffe0b2"),
    "strawberry": WordSpec("1F353", "#ffcdd2"),
    "pineapple": WordSpec("1F34D", "#fff59d"),
    "grapes": WordSpec("1F347", "#e1bee7"),
    # Animals
    "dog": WordSpec("1F436", "#dcedc8"),
    "cat": WordSpec("1F431", "#f0f4c3"),
    "elephant": WordSpec("1F418", "#e0f7fa"),
    "lion": WordSpec("1F981", "#ffe082"),
    "penguin": WordSpec("1F427", "#ede7f6"),
    "monkey": WordSpec("1F412", "#ffe0b2"),
    # Magic items
    "magic_hat": WordSpec("1F9D9", "#ede7f6"),
    "crystal_ball": WordSpec("1F52E", "#d1c4e9"),
    "spell_book": WordSpec("1F4D6", "#f3e5f5"),
    "magic_wand": WordSpec("1FA84", "#d1c4e9"),
    "potion": WordSpec("1F9EA", "#e3f2fd"),
    "flying_broom": WordSpec("1F9F9", "#ede7f6"),
    # Power items
    "power_sword": WordSpec("2694", "#fff3e0"),
    "treasure_map": WordSpec("1F5FA", "#ffe0b2"),
    "hero_shield": WordSpec("1F6E1", "#e0f7fa"),
    "energy_gauntlet": WordSpec("1F9BE", "#fbe9e7"),
    "magic_amulet": WordSpec("1F9FF", "#f3e5f5"),
    "dragon_armor": WordSpec("1F432", "#e8f5e9"),
    # Vehicles
    "car": WordSpec("1F697", "#e3f2fd"),
    "train": WordSpec("1F686", "#c5cae9"),
    "helicopter": WordSpec("1F681", "#bbdefb"),
    "submarine": WordSpec(None, "#b3e5fc", _draw_submarine),
    "bicycle": WordSpec("1F6B2", "#f1f8e9"),
    "hot_air_balloon": WordSpec(None, "#ffe0b2", _draw_hot_air_balloon),
    # Space exploration
    "astronaut": WordSpec("1F9D1-200D-1F680", "#cfd8dc"),
    "rocket": WordSpec("1F680", "#c5cae9"),
    "moon": WordSpec("1F315", "#e0f2f1"),
    "space_station": WordSpec("1F6F0", "#d7ccc8"),
    "satellite": WordSpec("1F4E1", "#cfd8dc"),
    "mars_rover": WordSpec(None, "#ffe0b2", _draw_mars_rover),
}


def _render_word(slug: str, spec: WordSpec) -> None:
    canvas = Image.new("RGBA", (ASSET_SIZE, ASSET_SIZE), spec.background)

    if spec.emoji_hex:
        icon = _fetch_openmoji(spec.emoji_hex)
        _resize_and_center(icon, canvas)
    elif spec.custom_renderer:
        draw = ImageDraw.Draw(canvas)
        spec.custom_renderer(draw)
    else:  # pragma: no cover - defensive fallback
        draw = ImageDraw.Draw(canvas)
        draw.text((ASSET_SIZE // 2, ASSET_SIZE // 2), slug, anchor="mm", fill="#37474f")

    output_path = OUTPUT_DIR / f"{slug}.png"
    canvas.save(output_path, format="PNG", optimize=True)
    logging.info("Saved %s", output_path)


def main() -> None:
    _ensure_cache_dir()
    for slug, spec in WORD_SPECS.items():
        _render_word(slug, spec)


if __name__ == "__main__":
    main()
