"""Assemble the four Android smoke-test captures into an article figure."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PANELS = (
    ("01-escaner.png", "A. Escáner"),
    ("02-diagnostico.png", "B. Diagnóstico"),
    ("03-reparacion.png", "C. Reparación"),
    ("04-historial.png", "D. Historial"),
)


def compose(directory, destination):
    width = 282
    gap = 18
    height = 626
    canvas = Image.new("RGB", (4 * width + 5 * gap, height + 70), "#eeede7")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=23)
    for index, (name, caption) in enumerate(PANELS):
        with Image.open(directory / name) as screenshot:
            panel = screenshot.convert("RGB")
        panel.thumbnail((width, height), Image.Resampling.LANCZOS)
        x = gap + index * (width + gap)
        y = 50
        draw.rectangle((x - 1, y - 1, x + panel.width, y + panel.height), outline="#a1a797", width=2)
        canvas.paste(panel, (x, y))
        draw.text((x + width // 2, 23), caption, fill="#202519", anchor="mm", font=font)
    canvas.save(destination, optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("screenshots", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    compose(args.screenshots, args.destination)
