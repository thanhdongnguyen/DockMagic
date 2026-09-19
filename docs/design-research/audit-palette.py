"""Read real DockMagic color assets and report contrast on opaque surfaces."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "DockMagic/DockMagic/Assets.xcassets"


def asset(name, dark):
    variants = json.loads((ASSETS / f"{name}.colorset/Contents.json").read_text())["colors"]
    entry = next(v for v in variants if any(a.get("value") == "dark" for a in v.get("appearances", [])) == dark)
    return [float(entry["color"]["components"][c]) for c in ["red", "green", "blue", "alpha"]]


def composite(fg, bg):
    return [fg[i] * fg[3] + bg[i] * (1 - fg[3]) for i in range(3)] + [1]


def luminance(color):
    channels = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in color[:3]]
    return sum(x * y for x, y in zip(channels, [0.2126, 0.7152, 0.0722]))


def contrast(fg, bg):
    a, b = luminance(composite(fg, bg)), luminance(bg)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


results = []
for dark in [False, True]:
    for surface in ["DSOpaqueSurface", "DSOpaqueSurfaceRaised", "DSOpaqueSurfaceInset"]:
        for foreground in ["DSTextPrimary", "DSTextSecondary", "DSTextTertiary", "DSActionForeground", "DSWarningForeground", "DSDangerForeground"]:
            ratio = contrast(asset(foreground, dark), asset(surface, dark))
            results.append(dict(mode="dark" if dark else "light", foreground=foreground, background=surface,
                                ratio=round(ratio, 3), threshold=4.5, passes=ratio >= 4.5))
    for foreground, background in [("DSOnAction", "DSAction"), ("DSOnWarning", "DSWarning"), ("DSOnDanger", "DSDanger")]:
        ratio = contrast(asset(foreground, dark), asset(background, dark))
        results.append(dict(mode="dark" if dark else "light", foreground=foreground, background=background,
                            ratio=round(ratio, 3), threshold=4.5, passes=ratio >= 4.5))

report = {
    "method": "sRGB relative luminance, alpha composited on named opaque background; no material/compositor proof",
    "pairs": results,
    "counterexample_white_on_light_action": round(contrast([1, 1, 1, 1], asset("DSAction", False)), 3),
}
out = Path(__file__).with_name("contrast-audit.json")
out.write_text(json.dumps(report, indent=2) + "\n")
print(f"{len(results)} text pairs; {sum(not r['passes'] for r in results)} below 4.5:1")
for r in results:
    if not r["passes"] or r["foreground"] in ["DSOnAction", "DSActionForeground"]:
        print(r)
print("White on light DSAction:", report["counterexample_white_on_light_action"])
