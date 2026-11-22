"""Writes the vector PDFs the app window draws from the SVG files beside them in Resources.

tian.svg is Rocco Casadei's personal mark, copied byte for byte from design/assets/mark of the
Roccobot/roccobot.github.io hub (tian-turchese.svg): its path is never modified, and the window
only changes its color. github.svg and telegram.svg are the official marks as drawn by Simple Icons
(CC0-1.0). The app uses the PDFs as template images, so only their shape counts.

Run it after changing one of the SVG files, where CairoSVG is installed (pip install cairosvg),
and commit the PDFs with them: macOS 13 reads PDF images, not SVG.

Author: Rocco Casadei, a.k.a. Roccobot
"""
from pathlib import Path

import cairosvg

resources = Path(__file__).resolve().parent.parent / 'Resources'
for name in ['tian', 'github', 'telegram']:
    cairosvg.svg2pdf(url=str(resources / f'{name}.svg'), write_to=str(resources / f'{name}.pdf'))
    print(resources / f'{name}.pdf')
