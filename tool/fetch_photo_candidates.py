"""Downloads candidate photos (free licences only) from Openverse for each category.
Writes candidates/<key>_<n>.jpg and candidates/credits.json. Run in CI (needs internet)."""
import json, os, pathlib, time, urllib.parse, urllib.request

out = pathlib.Path("candidates"); out.mkdir(exist_ok=True)
queries = json.load(open("tool/photo_queries.json"))
credits = {}
UA = {"User-Agent": "NukadKart/1.0 (category photos)"}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30).read()

for key, q in queries.items():
    params = urllib.parse.urlencode({
        "q": q, "license_type": "commercial,modification", "category": "photograph",
        "aspect_ratio": "square,wide", "size": "medium,large", "page_size": 20, "mature": "false",
    })
    try:
        data = json.loads(get(f"https://api.openverse.org/v1/images/?{params}"))
    except Exception as e:
        print("search failed", key, e); time.sleep(4); continue
    n = 0
    for r in data.get("results", []):
        if n >= 5: break
        if r.get("license") not in ("cc0", "pdm", "by", "by-sa"): continue
        url = r.get("thumbnail") or r.get("url")
        try:
            img = get(url)
            if len(img) < 8000: continue
        except Exception:
            continue
        name = f"{key}_{n}.jpg"
        (out / name).write_bytes(img)
        credits[name] = {k: r.get(k) for k in ("title", "creator", "license", "license_version", "foreign_landing_url", "source", "url")}
        n += 1
    print(key, n)
    time.sleep(3)
json.dump(credits, open(out / "credits.json", "w"), indent=1)
