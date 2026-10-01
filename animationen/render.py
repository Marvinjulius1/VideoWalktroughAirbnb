#!/usr/bin/env python3
"""
Rendert eine HTML-Animation aus templates/ als 1080x1920-MP4 (9:16, 30 fps).

Aufruf:
    python3 render.py <template> <ausgabe.mp4> [key=value ...]

Beispiel:
    python3 render.py counter ausgabe/zaehler.mp4 to=262481 prefix='$' bg=green

Jedes Template definiert window.DURATION und window.render(t). Der Renderer
setzt die Zeit Bild für Bild und macht davon Screenshots, dadurch laufen die
Animationen ruckelfrei und unabhängig von der Rechnerleistung.
"""

import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlencode

from playwright.sync_api import sync_playwright

FPS = 30
BREITE, HOEHE = 1080, 1920
TEMPLATES = Path(__file__).resolve().parent / "templates"
CHROMIUM = os.environ.get("CHROMIUM_PATH", "/opt/pw-browsers/chromium")


def render(template, ziel, params):
    url = (TEMPLATES / f"{template}.html").as_uri()
    if params:
        url += "?" + urlencode(params)
    Path(ziel).parent.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        launch = {"executable_path": CHROMIUM} if Path(CHROMIUM).exists() else {}
        browser = p.chromium.launch(**launch)
        page = browser.new_page(viewport={"width": BREITE, "height": HOEHE})
        page.goto(url)
        page.evaluate("document.fonts.ready")
        dauer = page.evaluate("window.DURATION")
        frames = round(dauer * FPS)

        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(FPS),
             "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "16",
             "-pix_fmt", "yuv420p", "-movflags", "+faststart", ziel],
            stdin=subprocess.PIPE,
        )
        for i in range(frames):
            page.evaluate(f"window.render({i / FPS})")
            ffmpeg.stdin.write(page.screenshot(type="png"))
        ffmpeg.stdin.close()
        if ffmpeg.wait() != 0:
            sys.exit("ffmpeg fehlgeschlagen")
        browser.close()
    print(f"{ziel}: {dauer:.1f} s, {frames} Bilder")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    render(sys.argv[1], sys.argv[2], dict(a.split("=", 1) for a in sys.argv[3:]))
