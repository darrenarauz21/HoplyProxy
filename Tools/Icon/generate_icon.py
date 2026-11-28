#!/usr/bin/env python3
"""Genera el ícono de Hoply (iOS y escritorio) a partir de una cuadrícula de píxeles.

Uso: python3 Tools/Icon/generate_icon.py  (requiere Pillow)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

PALETTE = {
    "A": (122, 170, 236),  # onda exterior: azul claro
    "B": (79, 141, 232),   # onda media
    "W": (61, 127, 224),   # onda interior: el acento de las apps (#3D7FE0)
    "T": (42, 98, 201),    # cuerpo del iPhone
    "D": (23, 63, 140),    # botón del iPhone
    "S": (234, 242, 252),  # pantalla
    "E": (22, 32, 46),     # ojos
}

# Señal de wifi cuyo punto es el iPhone con una cara.
GRID = [
    ".....AAAAAA.....",
    "...AAAAAAAAAA...",
    "..AAA......AAA..",
    ".AA...BBBB...AA.",
    ".A..BBBBBBBB..A.",
    "...BB......BB...",
    "......WWWW......",
    ".....WWWWWW.....",
    "................",
    ".....TTTTTT.....",
    ".....TSSSST.....",
    ".....TESSET.....",
    ".....TSSSST.....",
    ".....TSSSST.....",
    ".....TTDDTT.....",
    ".....TTTTTT.....",
]

IOS_BACKGROUND = (244, 247, 251, 255)  # fondo claro de la paleta (#F4F7FB)
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def pixel_art() -> Image.Image:
    image = Image.new("RGBA", (len(GRID[0]), len(GRID)), (0, 0, 0, 0))
    for y, row in enumerate(GRID):
        for x, key in enumerate(row):
            if key in PALETTE:
                image.putpixel((x, y), PALETTE[key] + (255,))
    return image


def scaled(art: Image.Image, size: int) -> Image.Image:
    return art.resize((size, size), Image.NEAREST)


def ios_icon(art: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), IOS_BACKGROUND)
    content = scaled(art, 832)
    canvas.alpha_composite(content, (96, 96))
    return canvas.convert("RGB")


def main() -> None:
    art = pixel_art()

    ios_path = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    ios_icon(art).save(ios_path)

    desktop_assets = ROOT / "Desktop/src/Hoply.Desktop/Assets"
    desktop_assets.mkdir(parents=True, exist_ok=True)
    scaled(art, 256).save(desktop_assets / "app.ico", sizes=ICO_SIZES)
    scaled(art, 256).save(desktop_assets / "logo.png")

    scaled(art, 512).save(ROOT / "App/Resources/Assets.xcassets/AppLogo.imageset/AppLogo.png")


if __name__ == "__main__":
    main()
