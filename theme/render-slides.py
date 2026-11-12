#!/usr/bin/env python3
"""Bake the AMOLED install progress panel for Calamares.

Usage: render-slides.py <calamares-brand-dir> <font-file> <fg> <fg-alt> <fg-muted> <border>

The Calamares image slideshow (SlideshowPictures) displays a plain pixmap and
has no text layer. Baking the copy into the same artwork as slide.png keeps the
install page AMOLED, keeps the text crisp at the native size, and avoids the
QQuickWidget white flash and QML font-timing problems.

Pillow is only needed when regenerating the committed PNG locally; the ISO and
CI use the checked-in image, just like the rest of theme/render-artwork.py.
"""
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not found; keeping the committed slide-install.png.")
    sys.exit(0)


def rgb(value):
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError("expected a 6-digit colour, got %r" % value)
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def load_font(path, size, weight):
    font = ImageFont.truetype(path, size)
    try:
        font.set_variation_by_name(weight)
    except Exception:
        pass
    return font


def tracked(draw, x, y, text, font, fill, tracking):
    for character in text:
        draw.text((x, y), character, font=font, fill=fill)
        x += font.getlength(character) + tracking


def main():
    if len(sys.argv) != 7:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    brand_dir = sys.argv[1]
    font_path = sys.argv[2]
    fg, fg_alt, fg_muted, border = (rgb(value) for value in sys.argv[3:7])

    base_path = os.path.join(brand_dir, "slide.png")
    out_path = os.path.join(brand_dir, "slide-install.png")
    if not os.path.isfile(base_path):
        print("missing %s; keeping the committed slide-install.png." % base_path)
        return 0
    if not os.path.isfile(font_path):
        print("missing %s; keeping the committed slide-install.png." % font_path)
        return 0

    try:
        image = Image.open(base_path).convert("RGB")
        draw = ImageDraw.Draw(image)

        # The image slideshow centres slide.png at its natural 1600x900 size
        # and clips it to the Calamares content area. The install copy lives in
        # the central 1000x650 safe area so it is visible both in the branding
        # window and in the fullscreen CI test window.
        left = 330
        draw.rectangle((left, 196, left + 40, 198), fill=fg)
        tracked(draw, left, 214, "KAADZOS INSTALLER",
                load_font(font_path, 17, "SemiBold"), fg_alt, 4)
        draw.text((left, 244), "Installing KaadzOS",
                  font=load_font(font_path, 56, "Bold"), fill=fg)
        draw.multiline_text(
            (left, 340),
            "The live system is being copied to disk.\n"
            "\n"
            "The AMOLED theme, Sway session and Waybar\n"
            "carry over unchanged. The installer removes\n"
            "itself on first boot.",
            font=load_font(font_path, 22, "Regular"),
            fill=fg_alt,
            spacing=10,
        )
        draw.rectangle((left, 700, left + 300, 701), fill=border)
        tracked(draw, left, 716, "KAADZOS  ·  DEBIAN TRIXIE  ·  SWAY / WAYLAND",
                load_font(font_path, 13, "Medium"), fg_muted, 2)

        image.save(out_path, optimize=True)
    except Exception as exc:
        print("Could not render %s (%s); keeping the committed image."
              % (out_path, exc))
        return 0

    print("Wrote", out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
