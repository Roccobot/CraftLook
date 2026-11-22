#!/usr/bin/env python3
"""Writes CraftLook's Sparkle appcast: the new release first, then the items of the appcast published
with the previous release, if any. Sparkle offers the highest build that the Mac can run.

    scripts/appcast.py --out appcast.xml --version 0.4.0 --build 12 --url URL --length BYTES
        --signature BASE64 --notes URL [--min-system 13.0] [--previous FILE_OR_URL]

The signature and length are what Sparkle's sign_update prints for the archive at URL. A build at or
below one already listed is refused, so a release cannot be offered twice or below an older one.
"""
import argparse
import email.utils
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape, quoteattr

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def item(version, build, url, length, signature, notes, min_system):
    return f"""    <item>
      <title>CraftLook {escape(version)}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{int(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape(min_system)}</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>{escape(notes)}</sparkle:fullReleaseNotesLink>
      <enclosure url={quoteattr(url)} length="{int(length)}" type="application/octet-stream" sparkle:edSignature={quoteattr(signature)}/>
    </item>
"""


def previous_items(source):
    """The <item> blocks of the published appcast, as text, or none when there is no appcast yet."""
    if not source:
        return "", []
    try:
        if "://" in source:
            with urllib.request.urlopen(source, timeout=60) as response:
                text = response.read().decode()
        else:
            text = open(source, encoding="utf-8").read()
    except (urllib.error.HTTPError, FileNotFoundError):
        return "", []
    builds = [int(e.text) for e in ET.fromstring(text).iter(f"{{{SPARKLE}}}version")]
    start, end = text.find("    <item>"), text.rfind("</item>")
    return (text[start:end + len("</item>")] + "\n" if start >= 0 else ""), builds


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    for name in ["out", "version", "build", "url", "length", "signature", "notes"]:
        parser.add_argument(f"--{name}", required=True)
    parser.add_argument("--min-system", default="13.0")
    parser.add_argument("--previous")
    args = parser.parse_args(argv)
    older, builds = previous_items(args.previous)
    if builds and int(args.build) <= max(builds):
        sys.exit(f"appcast: build {args.build} is not above the highest listed, {max(builds)}")
    text = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="{SPARKLE}">
  <channel>
    <title>CraftLook</title>
    <link>https://github.com/Roccobot/CraftLook</link>
    <description>Updates of CraftLook, Finder previews for ArtCraft projects.</description>
    <language>en</language>
{item(args.version, args.build, args.url, args.length, args.signature, args.notes, args.min_system)}{older}  </channel>
</rss>
"""
    ET.fromstring(text)
    with open(args.out, "w", encoding="utf-8") as target:
        target.write(text)
    print(f"appcast: CraftLook {args.version} (build {args.build}) first of {len(builds) + 1} in {args.out}")


if __name__ == "__main__":
    main(sys.argv[1:])
