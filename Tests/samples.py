#!/usr/bin/env python3
"""Write small projects for HeadlessCheck with the prepared renderers: python3 Tests/samples.py ENGINES OUT.

Each sample comes from its app's CLI (the built-in demo or a template), so none is kept in the repo.
The SVG draws its label with a real <text> element in a font family most Macs don't have."""
import json, pathlib, subprocess, sys, tempfile

SVG = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800">
  <rect x="60" y="20" width="680" height="760" rx="40" fill="#fff" stroke="#000" stroke-width="30"/>
  <rect x="40" y="290" width="720" height="320" rx="44" fill="#000"/>
  <text x="400" y="540" text-anchor="middle" font-family="'Source Sans 3', sans-serif" font-size="240"
        font-weight="bold" fill="#fff">MP4</text>
  <text transform="matrix(4 0 0 4 400 720)" text-anchor="middle" font-family="Georgia, serif" font-size="20"
        fill="#c00">video</text>
</svg>
'''

def main(engines, out):
    out.mkdir(parents=True, exist_ok=True)
    cli = lambda name: str(engines / name / f'{name}-cli')
    run = lambda *args: subprocess.run(args, check=True, stdout=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory() as tmp:
        script = pathlib.Path(tmp) / 'box.json'
        script.write_text(json.dumps([{'command': 'solid.box', 'params': {'length': 20, 'width': 16, 'height': 12}}]))
        run(cli('solidcraft'), 'run', str(script), '--save', str(out / 'box.sc'))
        graph = pathlib.Path(tmp) / 'pbr.sbs'
        run(cli('materialcraft'), 'new', 'pbr', str(graph))
        run(cli('materialcraft'), 'run', str(graph), 'file.save', json.dumps({'path': str(out / 'pbr.mcraft')}))
    (out / 'box.solidcraft').write_bytes((out / 'box.sc').read_bytes())
    run(cli('filmcraft'), '--demo', 'exec', 'file.saveAs', f'path={out / "demo.fcproj"}')
    for ext in ('ecproj', 'ecprojx'):
        run(cli('effectcraft'), '--demo', 'exec', 'file.saveAs', '--params', json.dumps({'path': str(out / f'demo.{ext}')}))
    (out / 'label.svg').write_text(SVG)
    print('\n'.join(sorted(str(p) for p in out.iterdir())))

if __name__ == '__main__':
    main(pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2]).resolve())
