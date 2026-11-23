"""Checks of the release scripts that need no network: python3 Tests/scripts_check.py

Author: Rocco Casadei, a.k.a. Roccobot
"""
import io
import pathlib
import sys
import urllib.error

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "scripts"))
import appcast  # noqa: E402

checks = 0


def answer(code):
    def urlopen(url, timeout=None):
        raise urllib.error.HTTPError(url, code, "test", {}, io.BytesIO())
    return urlopen


# A missing appcast (404) is a first release: no earlier items.
appcast.urllib.request.urlopen = answer(404)
assert appcast.previous_items("https://example.invalid/appcast.xml") == ("", []), "404"
checks += 1

# Any other answer stops the release: before 0.5.1 a rate limit or a server error published an
# appcast without the earlier versions.
for code in (403, 500, 503):
    appcast.urllib.request.urlopen = answer(code)
    try:
        appcast.previous_items("https://example.invalid/appcast.xml")
    except urllib.error.HTTPError:
        checks += 1
    else:
        raise AssertionError(f"HTTP {code} was taken for a missing appcast")

print(f"{checks} verifiche riuscite")
