#!/usr/bin/env python3
"""Rendert das Starter-Paket an Animationen nach ausgabe/ (parallel)."""

import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from render import render

AUSGABE = Path(__file__).resolve().parent / "ausgabe"

# (Ordner/Datei, Template, Parameter)
JOBS = [
    ("Zaehler/zaehler_zinseszins_262k", "counter",
     {"to": 262481, "label": "$100 a month · 40 years", "sub": "Only $48,000 invested"}),
    ("Zaehler/zaehler_0.01_prozent", "counter",
     {"to": 0.01, "decimals": 2, "prefix": "", "suffix": "%", "dur": 2.4}),
    ("Zaehler/zaehler_1_million", "counter", {"to": 1000000, "label": "Net worth"}),
    ("Zaehler/zaehler_48k_eingezahlt", "counter",
     {"to": 48000, "label": "What you put in", "dur": 2.6}),

    ("Charts/chart_portfolio_steigt", "chart",
     {"name": "Portfolio", "desc": "Last 10 years", "start": 10000, "end": 38700}),
    ("Charts/chart_portfolio_crash", "chart",
     {"name": "Portfolio", "desc": "Last 30 days", "start": 10000, "end": 6420, "seed": 3}),
    ("Charts/chart_krypto_steigt", "chart",
     {"name": "Crypto", "desc": "Last 12 months", "start": 1000, "end": 4380, "seed": 11}),
    ("Charts/balken_zinseszins", "bars", {}),

    ("Benachrichtigungen/benachrichtigung_zahlung", "notification", {"preset": "payment"}),
    ("Benachrichtigungen/benachrichtigung_dividende", "notification", {"preset": "dividend"}),
    ("Benachrichtigungen/benachrichtigung_krypto", "notification", {"preset": "crypto"}),
    ("Benachrichtigungen/benachrichtigung_verkaeufe", "notification", {"preset": "sales"}),

    ("Dynamic_Island/island_zahlung", "island", {}),
    ("Dynamic_Island/island_dividende", "island",
     {"title": "Portfolio", "subtitle": "Dividend received", "amount": 248.5, "icon": "%", "color": "#0a84ff"}),

    ("Tippfeld/tippfeld_1_prozent", "typing", {}),
    ("Tippfeld/tippfeld_erste_million", "typing", {"text": "How do I make my first $1,000,000?"}),
]

# Overlays come in a greenscreen version too.
OVERLAYS = ("notification", "island", "typing")


def job(args):
    name, template, params = args
    render(template, str(AUSGABE / f"{name}.mp4"), params)


if __name__ == "__main__":
    alle = []
    for name, template, params in JOBS:
        alle.append((name, template, params))
        if template in OVERLAYS:
            alle.append((name + "_greenscreen", template, {**params, "bg": "green"}))
    nur = sys.argv[1:]
    if nur:
        alle = [j for j in alle if any(n in j[0] for n in nur)]
    with ProcessPoolExecutor(4) as ex:
        list(ex.map(job, alle))
