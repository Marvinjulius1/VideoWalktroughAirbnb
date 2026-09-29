#!/usr/bin/env python3
"""
Airbnb-Walkthrough-Video aus Fotos erstellen.

Ken-Burns-Effekt (sanfter Zoom/Schwenk) pro Bild, weiche Überblendungen,
optionale Hintergrundmusik, Export als 1920x1080 MP4 (H.264 + AAC).

Aufruf:
    python3 make_walkthrough.py              # komplettes Video rendern
    python3 make_walkthrough.py --nur-musik  # nur Musik unter vorhandenes Video legen
                                             # (schnell, kein Neu-Rendern der Bilder)

Voraussetzungen: ffmpeg im PATH, Python-Pakete pillow + numpy
    pip install pillow numpy
"""

# =============================================================================
# KONFIGURATION – hier anpassen
# =============================================================================

FOTO_ORDNER = "fotos"
MUSIK_DATEI = "musik/track.mp3"
AUSGABE = "walkthrough.mp4"

BILD_DAUER = 3.5          # Sekunden, die jedes Bild sichtbar ist (inkl. Überblendung)
UEBERGANG_DAUER = 0.8     # Sekunden Überblendung zwischen zwei Bildern
FPS = 30
BREITE, HOEHE = 1920, 1080

ZOOM_STAERKE = 0.10       # 0.10 = 10 % Zoom über die Bilddauer
SCHWENK_STAERKE = 0.07    # Anteil der Bildbreite/-höhe, um den geschwenkt wird
MUSIK_FADE = 2.0          # Sekunden Ein-/Ausblenden der Musik
MUSIK_LAUTSTAERKE = 1.0   # 1.0 = Originallautstärke

# Bilder, deren Seitenverhältnis (Breite/Höhe) unter diesem Wert liegt
# (z. B. Hochformat), werden NICHT beschnitten, sondern vollständig gezeigt
# und mit einem weichgezeichneten Hintergrund aufgefüllt.
# 3:2-Querformat (1.5) wird dagegen auf 16:9 zugeschnitten (kein Rand).
MIN_SEITENVERHAELTNIS_FUER_ZUSCHNITT = 1.4

# Reihenfolge = begehbare Route. Dateinamen relativ zu FOTO_ORDNER.
# Zeilen einfach verschieben, auskommentieren (#) oder ergänzen.
# Optional pro Bild eine feste Bewegung: ("datei.jpg", "zoom_in")
# Mögliche Bewegungen: zoom_in, zoom_out, pan_links, pan_rechts,
# pan_hoch, pan_runter. Ohne Angabe wird automatisch abwechselnd variiert.
REIHENFOLGE = [
    # --- Ankunft: Straße, Einfahrt, Hausfront, Haustür
    "52.jpg",   # Straße mit Blick aufs Reetdachhaus
    "51.jpg",   # Einfahrt / Grundstück
    "53.jpg",   # Fassade mit Eingang
    "54.jpg",   # Seiteneingang, Tür offen
    "40.jpg",   # Blick durch die Haustür in den Flur
    # --- Erdgeschoss: Wohnbereich
    "09.jpg",   # vom Flur in den Wohnraum (Treppe links)
    "07.jpg",   # Wohnzimmer mit Sofa & TV
    "08.jpg",   # Wohnzimmer Richtung Terrassentüren
    "02.jpg",   # Wohnzimmer Übersicht
    "11.jpg",   # Wohnzimmer Blick zurück Richtung Treppe
    # --- Erdgeschoss: Essbereich & Küche
    "13.jpg",   # Esstisch mit Blick in den Wohnbereich
    "10.jpg",   # Esstisch & Küche
    "15.jpg",   # Essplatz am Fenster
    "05.jpg",   # Küche mit Delfter Fliesen
    "12.jpg",   # Küchenzeile
    "14.jpg",   # Kaffee-Ecke (Detail)
    # --- Erdgeschoss: Flur, Schlafzimmer & Bäder
    "33.jpg",   # Flur (Hochformat)
    "27.jpg",   # Treppe & Blick ins Schlafzimmer
    "28.jpg",   # Schlafzimmer mit Bad en suite
    "36.jpg",   # Schlafzimmer (Doppelbett, TV)
    "37.jpg",   # Schlafzimmer seitlich
    "38.jpg",   # Schlafzimmer mit Einbauschrank
    "34.jpg",   # zweites Schlafzimmer mit Schlafsofa
    "35.jpg",   # zweites Schlafzimmer, Kunstwand
    "30.jpg",   # Bad mit Doppelwaschtisch
    "29.jpg",   # Bad Übersicht (Hochformat)
    "31.jpg",   # Waschtisch
    "32.jpg",   # Dusche (Hochformat)
    # --- Obergeschoss: Schlafzimmer unterm Reetdach & Bad
    "16.jpg",   # Treppe oben, Blick ins Schlafzimmer
    "06.jpg",   # Schlafzimmer mit Gaube
    "17.jpg",   # Schlafzimmer Übersicht
    "18.jpg",   # Schlafzimmer mit Sekretär
    "19.jpg",   # Bett-Perspektive
    "21.jpg",   # Schlafzimmer mit TV-Schrank
    "20.jpg",   # Bett (Detail)
    "23.jpg",   # Bad OG, Blick von der Treppe
    "22.jpg",   # Bad OG Waschtisch & WC
    "24.jpg",   # Badewanne & Dusche
    "25.jpg",   # Badewanne
    "26.jpg",   # Dusche & Blick in den Flur
    # --- Raus auf die Terrasse
    "04.jpg",   # Terrasse direkt vor den Wohnzimmertüren
    "41.jpg",   # Terrasse mit Haus
    "42.jpg",   # Terrasse Übersicht
    "44.jpg",   # Lounge & Strandkorb
    "49.jpg",   # gedeckter Tisch
    "47.jpg",   # Strandkorb
    # --- Garten
    "48.jpg",   # Liegen im Garten
    "50.jpg",   # Doppelliege
    "46.jpg",   # Rasenfläche
    "01.jpg",   # Garten mit Kiefern
    # --- Sauna im Garten
    "43.jpg",   # Saunahaus
    "39.jpg",   # Saunatür (Hochformat)
    "03.jpg",   # Sauna innen
    # --- Abschluss: Blick aus dem Garten aufs Haus
    "45.jpg",
]

# =============================================================================
# AB HIER NORMALERWEISE NICHTS ÄNDERN
# =============================================================================

import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageFilter

BEWEGUNGEN = ["zoom_in", "pan_rechts", "zoom_out", "pan_links", "zoom_in", "pan_hoch", "zoom_out", "pan_runter"]


def pruefe_ffmpeg():
    if shutil.which("ffmpeg") is None:
        sys.exit(
            "FEHLER: ffmpeg wurde nicht gefunden.\n"
            "  Windows: winget install Gyan.FFmpeg   (danach Terminal neu starten)\n"
            "  macOS:   brew install ffmpeg\n"
            "  Linux:   sudo apt install ffmpeg"
        )


def lade_liste():
    liste = []
    for eintrag in REIHENFOLGE:
        datei, bewegung = (eintrag, None) if isinstance(eintrag, str) else eintrag
        pfad = os.path.join(FOTO_ORDNER, datei)
        if not os.path.isfile(pfad):
            print(f"WARNUNG: {pfad} nicht gefunden – wird übersprungen.")
            continue
        liste.append((pfad, bewegung))
    if not liste:
        sys.exit(f"FEHLER: Keine Bilder gefunden in '{FOTO_ORDNER}'.")
    return liste


def basisbild(pfad):
    """Bild auf 16:9 bringen, ohne es zu verzerren.

    Das Ergebnis ist etwas größer als das Video (Reserve für Zoom/Schwenk),
    damit auch beim Heranzoomen keine Ränder sichtbar werden.
    """
    reserve = 1.0 + max(ZOOM_STAERKE, SCHWENK_STAERKE) + 0.02
    W, H = round(BREITE * reserve), round(HOEHE * reserve)
    im = Image.open(pfad).convert("RGB")
    w, h = im.size
    ziel = W / H

    if w / h >= MIN_SEITENVERHAELTNIS_FUER_ZUSCHNITT:
        # Formatfüllend zuschneiden (Mitte)
        if w / h > ziel:
            nw = round(h * ziel)
            im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        else:
            nh = round(w / ziel)
            im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        return im.resize((W, H), Image.LANCZOS)

    # Hochformat o. Ä.: ganzes Bild zeigen, Hintergrund weichgezeichnet
    s = max(W / w, H / h)
    bg = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    bx, by = (bg.width - W) // 2, (bg.height - H) // 2
    bg = bg.crop((bx, by, bx + W, by + H)).filter(ImageFilter.GaussianBlur(40))
    bg = Image.eval(bg, lambda v: int(v * 0.6))  # abdunkeln, damit das Motiv hervorsticht
    s = min(W / w, H / h)
    fg = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    bg.paste(fg, ((W - fg.width) // 2, (H - fg.height) // 2))
    return bg


def weich(t):
    return t * t * (3 - 2 * t)  # sanftes Beschleunigen/Abbremsen


def ausschnitt(bewegung, t, W, H):
    """Liefert (x, y, breite, hoehe) des sichtbaren Ausschnitts im Basisbild."""
    t = weich(t)
    if bewegung in ("zoom_in", "zoom_out"):
        z = 1.0 + ZOOM_STAERKE * (t if bewegung == "zoom_in" else 1 - t)
        cw, ch = W / z, H / z
        return ((W - cw) / 2, (H - ch) / 2, cw, ch)

    # Schwenk: leicht gezoomter Ausschnitt, der über das Bild gleitet
    cw, ch = W / (1 + SCHWENK_STAERKE), H / (1 + SCHWENK_STAERKE)
    zoom_leicht = 1.0 + 0.03 * t  # minimaler Zoom macht den Schwenk lebendiger
    cw, ch = cw / zoom_leicht, ch / zoom_leicht
    fx, fy = (W - cw), (H - ch)
    if bewegung == "pan_rechts":
        x, y = fx * t, fy / 2
    elif bewegung == "pan_links":
        x, y = fx * (1 - t), fy / 2
    elif bewegung == "pan_runter":
        x, y = fx / 2, fy * t
    else:  # pan_hoch
        x, y = fx / 2, fy * (1 - t)
    return (x, y, cw, ch)


def frames_fuer_bild(basis, bewegung, anzahl):
    W, H = basis.size
    for i in range(anzahl):
        t = i / max(anzahl - 1, 1)
        x, y, cw, ch = ausschnitt(bewegung, t, W, H)
        # Subpixel-genaue Transformation => ruckelfreie Bewegung
        f = basis.transform(
            (BREITE, HOEHE), Image.EXTENT, (x, y, x + cw, y + ch), resample=Image.BICUBIC
        )
        yield np.asarray(f, dtype=np.uint8)


def render_video(bilder, ziel):
    n_bild = round(BILD_DAUER * FPS)
    n_ueber = min(round(UEBERGANG_DAUER * FPS), n_bild // 2)
    gesamt = len(bilder) * n_bild - (len(bilder) - 1) * n_ueber
    print(f"{len(bilder)} Bilder, Länge ca. {gesamt / FPS:.1f} s ({gesamt} Frames)")

    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{BREITE}x{HOEHE}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", ziel,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)

    rest = None  # letzte Frames des vorherigen Bildes (für die Überblendung)
    for idx, (pfad, bewegung) in enumerate(bilder):
        bewegung = bewegung or BEWEGUNGEN[idx % len(BEWEGUNGEN)]
        print(f"  [{idx + 1:>3}/{len(bilder)}] {os.path.basename(pfad):<12} {bewegung}")
        frames = frames_fuer_bild(basisbild(pfad), bewegung, n_bild)
        ist_letztes = idx == len(bilder) - 1
        neu_rest = []
        for i, f in enumerate(frames):
            if rest is not None and i < n_ueber:
                a = weich((i + 1) / (n_ueber + 1))
                f = (rest[i].astype(np.float32) * (1 - a) + f.astype(np.float32) * a).astype(np.uint8)
                proc.stdin.write(f.tobytes())
            elif not ist_letztes and i >= n_bild - n_ueber:
                neu_rest.append(f)
            else:
                proc.stdin.write(f.tobytes())
        rest = neu_rest

    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("FEHLER: ffmpeg-Encoding fehlgeschlagen.")


def videolaenge(pfad):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", pfad],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())


def musik_unterlegen(video, ziel):
    dauer = videolaenge(video)
    fade_out_start = max(dauer - MUSIK_FADE, 0)
    afilter = (
        f"volume={MUSIK_LAUTSTAERKE},"
        f"afade=t=in:st=0:d={MUSIK_FADE},"
        f"afade=t=out:st={fade_out_start:.2f}:d={MUSIK_FADE}"
    )
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", video,
        "-stream_loop", "-1", "-i", MUSIK_DATEI,  # Musik wird bei Bedarf wiederholt
        "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "copy", "-af", afilter, "-c:a", "aac", "-b:a", "192k",
        "-t", f"{dauer:.3f}", "-movflags", "+faststart", ziel,
    ]
    subprocess.run(cmd, check=True)


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    pruefe_ffmpeg()
    nur_musik = "--nur-musik" in sys.argv
    stumm = AUSGABE.replace(".mp4", "_ohne_musik.mp4")
    hat_musik = os.path.isfile(MUSIK_DATEI)

    if nur_musik:
        if not hat_musik:
            sys.exit(f"FEHLER: {MUSIK_DATEI} fehlt.")
        if not os.path.isfile(stumm):
            sys.exit(f"FEHLER: {stumm} fehlt – bitte zuerst ohne --nur-musik rendern.")
    else:
        render_video(lade_liste(), stumm)

    if hat_musik:
        print(f"Lege Musik unter: {MUSIK_DATEI}")
        musik_unterlegen(stumm, AUSGABE)
        print(f"Fertig: {AUSGABE} (mit Musik)")
    else:
        shutil.copyfile(stumm, AUSGABE)
        print(
            f"\nHINWEIS: {MUSIK_DATEI} nicht gefunden – {AUSGABE} wurde OHNE Musik erstellt.\n"
            f"  Lege eine MP3 unter {MUSIK_DATEI} ab und führe dann aus:\n"
            f"    python3 make_walkthrough.py --nur-musik\n"
            f"  (dauert nur Sekunden, die Bilder werden nicht neu gerendert)"
        )


if __name__ == "__main__":
    main()
