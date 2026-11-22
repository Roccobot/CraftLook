#!/usr/bin/env python3
"""Write small projects for HeadlessCheck with the prepared renderers: python3 Tests/samples.py ENGINES OUT.

Each sample comes from its app's CLI (the built-in demo or a template), so none is kept in the repo.
The SVG draws its label with a real <text> element in a font family most Macs don't have.
linked.svg is a tall 1200 x 2670 drawing that references a same-folder PNG, as Quick Look sees an
SVG with a local image. offline.fcproj covers the frame with a still that is then deleted, as Quick
Look sees a project whose media are elsewhere."""
import json, pathlib, struct, subprocess, sys, tempfile, zlib

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


LINKED = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="1200" height="2670" viewBox="0 0 1200 2670">
  <rect width="1200" height="2670" fill="#151b1a"/>
  <image x="271" y="361" width="658" height="658" xlink:href="swatch.png"/>
  <text x="1042" y="283" text-anchor="end"
        font-family="Roboto" font-weight="500" font-size="52" fill="#4fd9be">Ripristina</text>
</svg>
'''

def png(width, height, rgb):
    def chunk(tag, data): return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))
    rows = (b'\0' + bytes(rgb) * width) * height
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))

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
        still = pathlib.Path(tmp) / 'still.png'
        still.write_bytes(png(1920, 1080, (200, 40, 40)))
        offline = out / 'offline.fcproj'
        run(cli('filmcraft'), '--demo', 'exec', 'file.saveAs', f'path={offline}')
        imported = subprocess.run([cli('filmcraft'), '--project', str(offline), '--save', 'import', str(still), '--compact'],
                                  check=True, capture_output=True, text=True)
        item = json.loads(imported.stdout)['items'][0]
        head = json.loads(offline.read_text())['view']['playheads']
        seconds = max(head.values()) / 254_016_000_000
        run(cli('filmcraft'), '--project', str(offline), '--save', 'exec', 'timeline.place',
            json.dumps({'item': item, 'track': 'new', 'seconds': max(0, seconds - 1), 'duration': {'seconds': 3}}))
    (out / 'box.solidcraft').write_bytes((out / 'box.sc').read_bytes())
    run(cli('filmcraft'), '--demo', 'exec', 'file.saveAs', f'path={out / "demo.fcproj"}')
    for ext in ('ecproj', 'ecprojx'):
        run(cli('effectcraft'), '--demo', 'exec', 'file.saveAs', '--params', json.dumps({'path': str(out / f'demo.{ext}')}))
    (out / 'label.svg').write_text(SVG)
    (out / 'swatch.png').write_bytes(png(64, 64, (0, 200, 40)))
    (out / 'linked.svg').write_text(LINKED)
    print('\n'.join(sorted(str(p) for p in out.iterdir() if not p.name.startswith('.'))))

if __name__ == '__main__':
    main(pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2]).resolve())
