#!/usr/bin/env python3
"""Prepare the pinned upstream CLI archives, Sparkle and their notices for build.sh."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import urllib.request
from zipfile import ZipFile

# Product: (version, SHA-256 of its official macos-universal CLI ZIP, GitHub repository).
# The ZIP is still the upstream universal archive; after the checksum, only the arm64 slice is kept.
# Always the latest release, pre-releases included, nightly builds excluded (Rules.md).
RENDERERS = {
    "figcraft": ("0.18.1", "87efbca334e0925fce328ede159faef2df781b2a167d573888044127bfd4b0de", "storytold/figcraft"),
    "designcraft": ("0.20.1", "a178783b31e1af48f7af2b516568ec85537a484dfbcc5057b0f03cadee90c0ab", "storytold/designcraft"),
    "vectorcraft": ("0.24.1", "7f0c8261e5c831d9681e48272f9ba73bf8702dbf6ceb84f98177c7c007faddf2", "storytold/vectorcraft"),
    "texturecraft": ("0.6.1", "80a65494a740d100797d54a55c43ff32ee40ee19678eebae8200f52cbba33bdc", "storytold/texturecraft"),
    "solidcraft": ("0.46.2", "c46a6a5ac3068c9de75195b2235d8be6d90024d3426de5fc0f3967065477445b", "tangency-labs/solidcraft"),
    "filmcraft": ("0.20.1", "1651d9defb54f853cbd69016428bb9f72a7bf26d56e4755b8e2a79535fd0ac82", "storytold/filmcraft"),
    "materialcraft": ("0.4.1", "bcf0e87191dfca39ba14c8110823b21ed5bc5078ad7ae8e4cff380d83fec6edc", "storytold/materialcraft"),
    "effectcraft": ("0.24.1", "2781eda194372ad47f4c0c7df8b1d38501a3e90bb499282f57e9598a85958673", "storytold/effectcraft"),
}
# Sparkle 2, the updater of the app: version, SHA-256 of its release archive, repository. Also at its
# latest release, pre-releases included.
SPARKLE = ("2.11.0-beta.1", "896daf5116e4edb12d00cc6f87ce1ca90fff1e106c1cbb07988bcdbf3ce38c4c", "sparkle-project/Sparkle")


def checksum(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()



def thin_to_arm64(path):
    """Keep only the arm64 slice of a Mach-O, in place. Non-Mach-O files are left alone."""
    try:
        archs = subprocess.check_output(["lipo", "-archs", path], stderr=subprocess.DEVNULL, text=True).split()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return
    if "arm64" not in archs and "arm64e" not in archs:
        raise ValueError(f"{path} has no arm64 slice (archs: {' '.join(archs)})")
    if "x86_64" not in archs:
        return
    tmp = path.with_name(path.name + ".arm64")
    subprocess.run(["lipo", "-thin", "arm64", path, "-output", tmp], check=True)
    tmp.replace(path)


def thin_tree(root):
    for item in root.rglob("*"):
        if item.is_file() and not item.is_symlink():
            thin_to_arm64(item)


def prepare(output, archives, product, version, expected, repo):
    folder = f"{product}-cli-{version}-macos-universal"
    filename = folder + ".zip"
    with tempfile.TemporaryDirectory(dir=output) as tmp:
        scratch = Path(tmp)
        archive = archives / filename if archives else scratch / filename
        if not archives:
            url = f"https://github.com/{repo}/releases/download/v{version}/{filename}"
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
        thin_to_arm64(stage / executable)
        target = output / product
        if target.exists():
            # Re-running against a prepared directory is safe. Keep user-edited
            # files intact if an existing directory belongs to another build.
            # A directory prepared before 0.5.0 may still hold a universal CLI: thin it first.
            thin_to_arm64(target / executable)
            paths = [item.relative_to(stage) for item in stage.rglob("*") if item.is_file()]
            if not all((target / p).is_file() and checksum(target / p) == checksum(stage / p) for p in paths):
                raise ValueError(f"{target} contains a different renderer. Choose another output directory.")
            (target / executable).chmod(0o755)
        else:
            stage.rename(target)
        print(f"{product} {version} verified", flush=True)


def prepare_sparkle(output, archives, version, expected, repo):
    """Sparkle.framework (arm64 slice), sign_update and generate_keys for scripts/release.sh, and the license."""
    filename = f"Sparkle-{version}.tar.xz"
    target = output / "sparkle"
    if (target / "VERSION").is_file():
        if (target / "VERSION").read_text().strip() != version:
            raise ValueError(f"{target} contains another Sparkle. Choose another output directory.")
        thin_tree(target)
        print(f"sparkle {version} verified", flush=True)
        return
    with tempfile.TemporaryDirectory(dir=output) as tmp:
        scratch = Path(tmp)
        archive = archives / filename if archives else scratch / filename
        if not archives:
            url = f"https://github.com/{repo}/releases/download/{version}/{filename}"
            with urllib.request.urlopen(url, timeout=120) as source, archive.open("wb") as target_file:
                shutil.copyfileobj(source, target_file)
        if checksum(archive) != expected:
            raise ValueError(f"Unexpected SHA-256 for {filename}")
        stage = scratch / "sparkle"
        stage.mkdir()
        # bsdtar keeps the framework's symbolic links.
        subprocess.run(["tar", "-xf", archive, "-C", stage, "./Sparkle.framework", "./bin/sign_update",
                        "./bin/generate_keys", "./LICENSE"], check=True)
        (stage / "VERSION").write_text(version + "\n")
        thin_tree(stage)
        stage.rename(target)
    print(f"sparkle {version} verified", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--archives", type=Path, help="Use downloaded ZIPs, with their original filenames.")
    parser.add_argument("--list", action="store_true", help="Print the renderer names, one per line, for build.sh.")
    options = parser.parse_args()
    if options.list:
        print("\n".join(RENDERERS))
        raise SystemExit
    if options.output is None:
        parser.error("the output directory is required")
    options.output.mkdir(parents=True, exist_ok=True)
    for name, (release, digest, repo) in RENDERERS.items():
        prepare(options.output, options.archives, name, release, digest, repo)
    prepare_sparkle(options.output, options.archives, *SPARKLE)
