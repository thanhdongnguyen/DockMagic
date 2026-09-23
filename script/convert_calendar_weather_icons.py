"""Convert approved ImageGen PNG weather pictograms to compact vector assets.

Usage: PYTHONPATH=/path/to/vtracer python3 script/convert_calendar_weather_icons.py
Source PNGs are kept in docs/design/calendar-weather-icons/sources for auditability.
"""

from pathlib import Path
import json

from PIL import Image
import vtracer


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/calendar-weather-icons/sources"
ASSETS = ROOT / "DockMagic/DockMagic/Assets.xcassets"
NAMES = ("Sun", "PartlyCloudy", "Cloud", "Wind", "Rain", "Ice", "Storm", "Moon")

for name in NAMES:
    source = SOURCE / f"{name.lower()}.png"
    destination = ASSETS / f"CalendarWeather{name}.imageset"
    destination.mkdir(parents=True, exist_ok=True)
    image = Image.open(source).convert("RGBA")
    # ImageGen's transparent edges contain subpixel noise. Flatten alpha and
    # quantize before tracing so the SVG contains intentional, legible shapes.
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 120 else 0)
    image.putalpha(alpha)
    palette = image.convert("RGB").quantize(colors=8, method=Image.Quantize.FASTOCTREE)
    flattened = palette.convert("RGBA")
    flattened.putalpha(alpha)
    working = destination / "trace-input.png"
    flattened.save(working)
    vtracer.convert_image_to_svg_py(
        str(working), str(destination / "icon.svg"),
        colormode="color", hierarchical="stacked", mode="spline",
        filter_speckle=12, color_precision=4, layer_difference=16,
        corner_threshold=60, length_threshold=4, max_iterations=10,
        splice_threshold=45, path_precision=2,
    )
    working.unlink()
    (destination / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }, indent=2) + "\n")
