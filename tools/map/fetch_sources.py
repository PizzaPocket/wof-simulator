"""Download the source maps from the Wings of Fire wiki into cache/maps/.

The images are not committed (the repo is public), so run this first.
"""
import json
import pathlib
import urllib.parse
import urllib.request
import urllib.error

API = "https://wingsoffire.fandom.com/api.php"
FILES = [
    "PyrrhiaColored.png", "Pyrrhia AGttDW.png",
    "PantalaColored.jpg", "Pantala AGttDW.jpg", "Forgotten Isles Map.jpg",
    "NightWing island (a guide to the dragon world BN preview, wings of fire).jpg",
]
OUT = pathlib.Path(__file__).resolve().parents[2] / "cache" / "maps"
# The wiki rejects urllib's default user agent.
HEADERS = {"User-Agent": "wof-pyrrhia-map-tools/0.1 (personal project)"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=30)


def image_url(title):
    query = urllib.parse.urlencode({
        "action": "query", "titles": f"File:{title}",
        "prop": "imageinfo", "iiprop": "url", "format": "json",
    })
    with get(f"{API}?{query}") as resp:
        pages = json.load(resp)["query"]["pages"]
    return next(iter(pages.values()))["imageinfo"][0]["url"]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for title in FILES:
        dest = OUT / title
        if dest.exists():
            print(f"have {dest.name}")
            continue
        # format=original asks the CDN for the uploaded file rather than a WebP copy
        url = image_url(title) + "&format=original"
        try:
            response = get(url)
        except urllib.error.HTTPError as error:
            if error.code != 403:
                raise
            # The revision CDN sometimes denies downloads; the legacy image
            # endpoint still serves the same uploaded source (possibly WebP).
            fallback = image_url(title).split("/revision/")[0].replace(
                "static.wikia.nocookie.net", "images.wikia.com")
            response = get(fallback)
        with response as resp:
            if not resp.headers.get("Content-Type", "").startswith("image/"):
                raise ValueError(f"Expected image data for {title}")
            dest.write_bytes(resp.read())
        print(f"saved {dest.name}")


if __name__ == "__main__":
    main()
