#!/usr/bin/env python3
"""Prepare the pinned upstream CLI archives and their notices for build.sh."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import urllib.request
from zipfile import ZipFile

RENDERERS = {
    "figcraft": ("0.18.1", "87efbca334e0925fce328ede159faef2df781b2a167d573888044127bfd4b0de"),
    "designcraft": ("0.20.1", "a178783b31e1af48f7af2b516568ec85537a484dfbcc5057b0f03cadee90c0ab"),
    "vectorcraft": ("0.24.1", "7f0c8261e5c831d9681e48272f9ba73bf8702dbf6ceb84f98177c7c007faddf2"),
    "texturecraft": ("0.6.1", "80a65494a740d100797d54a55c43ff32ee40ee19678eebae8200f52cbba33bdc"),
}


def checksum(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def prepare(output, archives, product, version, expected):
    folder = f"{product}-cli-{version}-macos-universal"
    filename = folder + ".zip"
    with tempfile.TemporaryDirectory(dir=output) as tmp:
        scratch = Path(tmp)
        archive = archives / filename if archives else scratch / filename
        if not archives:
            url = f"https://github.com/storytold/{product}/releases/download/v{version}/{filename}"
            with urllib.request.urlopen(url, timeout=120) as source, archive.open("wb") as target:
                shutil.copyfileobj(source, target)
        if checksum(archive) != expected:
            raise ValueError(f"Unexpected SHA-256 for {filename}")
        stage = scratch / product
        executable = product + "-cli"
        with ZipFile(archive) as bundle:
            for member in bundle.infolist():
                if member.is_dir():
                    continue
                relative = PurePosixPath(member.filename).relative_to(folder)
                if relative.is_absolute() or ".." in relative.parts:
                    raise ValueError(f"Unexpected member in {filename}")
                dest = (stage if str(relative) == executable else stage / "Notices") / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(member) as source, dest.open("wb") as target:
                    shutil.copyfileobj(source, target)
        (stage / executable).chmod(0o755)
        target = output / product
        if target.exists():
            # Re-running against a prepared directory is safe. Keep user-edited
            # files intact if an existing directory belongs to another build.
            paths = [item.relative_to(stage) for item in stage.rglob("*") if item.is_file()]
            if not all((target / p).is_file() and checksum(target / p) == checksum(stage / p) for p in paths):
                raise ValueError(f"{target} contains a different renderer. Choose another output directory.")
            (target / executable).chmod(0o755)
        else:
            stage.rename(target)
        print(f"{product} {version} verified", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--archives", type=Path, help="Use downloaded ZIPs, with their original filenames.")
    options = parser.parse_args()
    options.output.mkdir(parents=True, exist_ok=True)
    for name, (release, digest) in RENDERERS.items():
        prepare(options.output, options.archives, name, release, digest)
