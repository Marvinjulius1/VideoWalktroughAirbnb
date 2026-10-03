#!/usr/bin/env python3
"""
Erzeugt den Voiceover eines Videos immer mit derselben Stimme (stimme.json).

Aufruf:
    python3 voiceover.py <saetze.txt> <ausgabe.wav> [laenge_in_s]

saetze.txt: eine Zeile pro Satz im Format  <startzeit_s> | <text> [| <tempo>]
    3.1  | That's what most people think.
    22.1 | The rich didn't start with more money. They started earlier. | +8%

Jeder Satz wird einzeln erzeugt, Stille am Rand wird abgeschnitten und der Satz
genau an seine Startzeit gelegt. Danach wird alles auf -16 LUFS normalisiert.
"""

import asyncio
import json
import ssl
import subprocess
import sys
import tempfile
from pathlib import Path

import edge_tts
import edge_tts.communicate

# Hinter einem TLS-Proxy die dort hinterlegte CA nutzen (edge-tts liest sonst nur certifi).
CA = Path("/root/.ccr/ca-bundle.crt")
if CA.exists():
    edge_tts.communicate._SSL_CTX = ssl.create_default_context(cafile=str(CA))

CONFIG = json.loads((Path(__file__).resolve().parent / "stimme.json").read_text())
TRIM = ("silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-50dB,areverse")


def satz(text, ziel, rate):
    mp3 = ziel.with_suffix(".mp3")
    asyncio.run(edge_tts.Communicate(text, CONFIG["voice"], rate=rate, pitch=CONFIG["pitch"]).save(str(mp3)))
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(mp3), "-af", TRIM,
                    "-ar", "48000", "-ac", "2", str(ziel)], check=True)


def main(saetze, ausgabe, laenge=None):
    zeilen = [z.split("|") for z in Path(saetze).read_text().splitlines() if z.strip() and not z.startswith("#")]
    with tempfile.TemporaryDirectory() as tmp:
        ins, filt = [], []
        for k, teile in enumerate(zeilen):
            start, text = float(teile[0]), teile[1].strip()
            rate = teile[2].strip() if len(teile) > 2 else CONFIG["rate"]
            wav = Path(tmp) / f"{k:02d}.wav"
            satz(text, wav, rate)
            ms = int(start * 1000)
            ins += ["-i", str(wav)]
            filt.append(f"[{k}]adelay={ms}|{ms}[a{k}]")
        ende = f",apad=whole_dur={laenge},atrim=0:{laenge}" if laenge else ""
        mix = (";".join(filt) + ";" + "".join(f"[a{k}]" for k in range(len(zeilen)))
               + f"amix=inputs={len(zeilen)}:normalize=0{ende},loudnorm=I={CONFIG['loudness_lufs']}:TP=-1.5[m]")
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", *ins, "-filter_complex", mix,
                        "-map", "[m]", "-ar", "48000", ausgabe], check=True)
    print(f"{ausgabe}: {len(zeilen)} Sätze, Stimme {CONFIG['name']}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], *sys.argv[3:])
