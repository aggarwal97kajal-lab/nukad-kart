"""Downloads candidate photos (free licences only) for each category from Wikimedia Commons.
Writes candidates/<key>_<n>.jpg and candidates/credits.json. Run in CI (needs internet)."""
import json, pathlib, time, urllib.parse, urllib.request, re

out = pathlib.Path("candidates"); out.mkdir(exist_ok=True)
queries = json.load(open("tool/photo_queries.json"))
credits = {}
UA = {"User-Agent": "NukadKartBot/1.0 (https://github.com/aggarwal97kajal-lab/nukad-kart)"}
API = "https://commons.wikimedia.org/w/api.php"

def get(url, tries=3):
    for i in range(tries):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read()
        except Exception as e:
            if i == tries - 1: raise
            time.sleep(3 * (i + 1))

def strip(html):
    return re.sub(r"<[^>]+>", "", html or "").strip()

for key, q in queries.items():
    params = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
        "gsrsearch": f"{q} filetype:bitmap", "gsrlimit": 25,
        "prop": "imageinfo", "iiprop": "url|extmetadata|size", "iiurlwidth": 600,
    })
    try:
        data = json.loads(get(f"{API}?{params}"))
    except Exception as e:
        print("search failed", key, e); continue
    pages = sorted((data.get("query", {}).get("pages", {}) or {}).values(), key=lambda p: p.get("index", 99))
    n = 0
    for p in pages:
        if n >= 6: break
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        lic = strip(meta.get("LicenseShortName", {}).get("value", ""))
        if not re.search(r"CC0|Public domain|CC BY", lic, re.I) or re.search(r"NC|ND", lic): continue
        if ii.get("width", 0) < 500 or ii.get("height", 0) < 400: continue
        thumb = ii.get("thumburl")
        if not thumb or not thumb.lower().endswith((".jpg", ".jpeg")): continue
        try:
            img = get(thumb)
        except Exception:
            continue
        name = f"{key}_{n}.jpg"
        (out / name).write_bytes(img)
        credits[name] = {"title": p.get("title"), "creator": strip(meta.get("Artist", {}).get("value", "")),
                         "license": lic, "page": ii.get("descriptionurl")}
        n += 1
    print(key, n)
    time.sleep(1)
json.dump(credits, open(out / "credits.json", "w"), indent=1)
