#!/usr/bin/env python3
"""Builds SCYDE's footage and music pack from freely licensed Wikimedia Commons media.

Only files whose Commons licence is CC0, public domain or CC BY are used. Every item
keeps its title, author, licence and source page in manifest.json so the app can credit it.

Usage: build_pack.py <out-dir>
"""
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "SCYDE-media-pack/1.0 (https://scyde.dev; https://github.com/mmzlopasa/scydenet)"
OK_LICENSES = ("cc0", "public domain", "pd", "cc by 4.0", "cc by 3.0", "cc by 2.5", "cc by 2.0")
BLOCK = re.compile(
    r"nude|naked|sex|porn|erotic|blood|corpse|dead|death|kill|war\b|weapon|gun|shoot|shot\b|execution|nazi|riot|"
    r"accident|crash|injur|surgery|autopsy|hunting|slaughter|police|sheriff|deputy|suspect|bodycam|arrest|chase|"
    r"fight|protest|attack|bomb|military|army|missile|fire department|funeral|prison|drug|smok|cigar|alcohol|beer|"
    r"politic|president|election|campaign|religio|church service|sora|openai|ai generated|nasa animation|ntsb|"
    r"scp|test\b|hell|zombie|horror|lion cub|reel-|setaf|interview|lecture|news|documentary|trailer",
    re.I,
)
# Stock-footage sources on Commons (their uploads are CC0 and look like stock).
SOURCES = ['insource:"pexels.com"', 'insource:"pixabay.com"', 'insource:"videvo"', 'insource:"mixkit"']

VIDEO_QUERIES = {
    "cars": ["car driving road", "sports car", "highway traffic aerial", "car interior driving"],
    "travel": ["aerial drone city", "beach drone", "airplane window clouds", "mountain road aerial"],
    "vlog": ["coffee shop", "city street walking", "skateboard", "bicycle city"],
    "beat": ["neon lights", "concert lights", "dj party lights", "light painting"],
    "cinematic": ["sunset timelapse", "mountains clouds timelapse", "fog forest", "desert dunes"],
    "retro": ["vintage film 8mm", "old car", "vinyl record player", "arcade"],
    "minimal": ["ocean waves", "white sand", "rain window", "ink water"],
    "slideshow": ["flowers bloom", "autumn leaves", "garden", "sky clouds"],
    "birthday": ["fireworks", "candles cake", "balloons", "confetti"],
    "fitness": ["running athlete", "gym workout", "yoga", "cycling road"],
    "food": ["cooking pan", "coffee pour", "pizza", "fruit"],
    "fashion": ["fabric texture", "shoes", "sunglasses", "jewelry"],
    "product": ["watch close up", "smartphone", "camera lens", "headphones"],
    "realEstate": ["house aerial", "interior living room", "apartment building", "swimming pool"],
    "sports": ["surfing", "skiing", "football stadium", "basketball"],
    "wedding": ["wedding", "rings", "roses", "church bells"],
    "pets": ["dog running", "cat", "puppy", "kitten"],
    "nature": ["waterfall", "forest", "lake", "birds flying"],
    "night": ["city night traffic", "night sky stars", "night city aerial", "street lights night"],
    "intro": ["abstract light", "particles", "smoke", "bokeh"],
}
VIDEOS_PER_CATEGORY = 4

# Extra search terms used only when building candidate sheets.
EXTRA_QUERIES = {
    "cars": ["vintage car", "car rally", "electric car", "race track"],
    "travel": ["aerial view coast", "drone footage island", "eiffel tower", "venice canal"],
    "vlog": ["street market", "tram city", "people walking park", "train station"],
    "beat": ["laser show", "led lights", "fireworks night", "carnival"],
    "cinematic": ["timelapse clouds", "aurora borealis", "milky way timelapse", "volcano"],
    "retro": ["steam locomotive", "classic car", "jukebox", "typewriter"],
    "minimal": ["water drops", "sand dunes", "snow falling", "calm lake"],
    "slideshow": ["tulips", "cherry blossom", "butterfly", "sunflower"],
    "birthday": ["fireworks display", "party", "celebration", "cake"],
    "fitness": ["marathon", "swimming", "climbing", "skateboarding"],
    "food": ["bakery", "barbecue", "sushi", "market vegetables"],
    "fashion": ["runway", "textile", "sewing", "dress"],
    "product": ["clock mechanism", "keyboard typing", "smartwatch", "lamp"],
    "realEstate": ["villa", "kitchen interior", "skyscraper", "garden house"],
    "sports": ["tennis", "cycling race", "sailing", "snowboard"],
    "wedding": ["bride", "wedding dance", "bouquet", "wedding car"],
    "pets": ["horse", "parrot", "rabbit", "dogs playing"],
    "nature": ["mountain lake", "river", "wildflowers", "sea turtle"],
    "night": ["city lights timelapse", "moon", "night bridge", "neon city"],
    "intro": ["light leaks", "ink in water", "paint mixing", "glitter"],
}

MUSIC_QUERIES = {
    "Upbeat": ["Kevin MacLeod upbeat", "happy upbeat music"],
    "Cinematic": ["Kevin MacLeod cinematic", "epic orchestral"],
    "Electronic": ["Kevin MacLeod electronic", "electronic music"],
    "Chill": ["Kevin MacLeod chill", "ambient music"],
    "Rock": ["Kevin MacLeod rock", "rock instrumental"],
    "Piano": ["piano Musopen", "Kevin MacLeod piano"],
    "Funk": ["Kevin MacLeod funk", "funk music"],
    "Classical": ["Musopen orchestra", "Musopen string quartet"],
}
TRACKS_PER_GENRE = 3


def api(params):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001
            print("api retry", attempt, e, flush=True)
            time.sleep(2 + attempt * 3)
    return {}


def clean(text):
    text = re.sub(r"<[^>]+>", "", text or "")
    return html.unescape(text).strip()[:120]


def search(query, kind, source=""):
    data = api({
        "action": "query",
        "generator": "search",
        "gsrnamespace": 6,
        "gsrsearch": f"{query} filetype:{kind} {source}".strip(),
        "gsrlimit": 40,
        "prop": "videoinfo",
        "viprop": "url|size|mime|mediatype|extmetadata|derivatives",
        "viurlwidth": 320,
        "viextmetadatafilter": "LicenseShortName|Artist|ObjectName",
    })
    pages = (data.get("query") or {}).get("pages") or []
    out = []
    for p in pages:
        info = (p.get("videoinfo") or [None])[0]
        if not info:
            continue
        meta = info.get("extmetadata") or {}
        lic = clean((meta.get("LicenseShortName") or {}).get("value", ""))
        if not lic.lower().startswith(OK_LICENSES):
            continue
        title = p.get("title", "")
        name = clean((meta.get("ObjectName") or {}).get("value", "")) or title.replace("File:", "")
        if BLOCK.search(title) or BLOCK.search(name):
            continue
        out.append({
            "title": name,
            "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
            "author": clean((meta.get("Artist") or {}).get("value", "")) or "Unknown",
            "license": lic,
            "url": info.get("url"),
            "thumb": info.get("thumburl"),
            "page_title": title,
            "width": info.get("width") or 0,
            "height": info.get("height") or 0,
            "duration": float(info.get("duration") or 0),
            "size": info.get("size") or 0,
            "derivatives": info.get("derivatives") or [],
            "rank": (0 if lic.lower().startswith(("cc0", "public domain", "pd")) else 1) + (0 if source else 2),
        })
    return out


def best_video_source(c):
    """A derivative around 720p if there is one (small download), else the original."""
    good = [d for d in c["derivatives"] if d.get("src") and 480 <= int(d.get("height") or 0) <= 1080]
    good.sort(key=lambda d: abs(int(d.get("height") or 0) - 720))
    if good:
        return good[0]["src"]
    return c["url"]


def fetch(url, path):
    """Polite download: one request at a time, honours 429 Retry-After, retries with backoff."""
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
                while True:
                    chunk = r.read(1 << 16)
                    if not chunk:
                        break
                    f.write(chunk)
            time.sleep(1.0)
            return True
        except urllib.error.HTTPError as e:
            wait = int(e.headers.get("Retry-After") or 0) or (5 * (attempt + 1))
            print(f"download {e.code}, waiting {wait}s", flush=True)
            if e.code in (404, 410):
                return False
            time.sleep(min(wait, 60))
        except Exception as e:  # noqa: BLE001
            print("download error", e, flush=True)
            time.sleep(5 * (attempt + 1))
    return False


def run(cmd, timeout=240):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if r.returncode != 0:
            print("ffmpeg failed:", r.stderr[-400:], flush=True)
        return r.returncode == 0
    except subprocess.TimeoutExpired:
        print("ffmpeg timeout", flush=True)
        return False


TMP = "/tmp/scyde-src"


def make_clip(c, out_path):
    src = best_video_source(c)
    if c["size"] and c["size"] > 400_000_000 and src == c["url"]:
        return False
    if not fetch(src, TMP):
        return False
    dur = c["duration"] or 12
    start = max(0.0, min(dur * 0.25, dur - 6)) if dur > 7 else 0
    vf = ("scale=w='if(gt(iw,ih),960,-2)':h='if(gt(iw,ih),-2,960)',"
          "fps=30,format=yuv420p")
    return run(["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.2f}", "-i", TMP,
                "-t", "5", "-an", "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "25",
                "-movflags", "+faststart", out_path])


def make_track(c, out_path):
    if c["size"] and c["size"] > 150_000_000:
        return False
    if not fetch(c["url"], TMP):
        return False
    return run(["ffmpeg", "-y", "-loglevel", "error", "-i", TMP, "-t", "90",
                "-af", "afade=t=in:d=0.5,afade=t=out:st=86:d=4", "-vn", "-c:a", "aac", "-b:a", "128k",
                "-movflags", "+faststart", out_path], timeout=300)


def probe(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width,height:format=duration",
                        "-of", "json", path], capture_output=True, text=True)
    try:
        j = json.loads(r.stdout)
        s = (j.get("streams") or [{}])[0]
        return int(s.get("width") or 0), int(s.get("height") or 0), float(j["format"]["duration"])
    except Exception:  # noqa: BLE001
        return 0, 0, 0.0


def candidates(out):
    """Contact sheets of the best-looking search results per category, for human curation."""
    os.makedirs(out, exist_ok=True)
    listing = {}
    font = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    for cat, queries in VIDEO_QUERIES.items():
        pool, seen = [], set()
        for q in queries + EXTRA_QUERIES.get(cat, []):
            for c in search(q, "video"):
                if c["page"] in seen or (c["width"] < 1200 and c["height"] < 1200):
                    continue
                if c["duration"] and (c["duration"] < 4 or c["duration"] > 900):
                    continue
                seen.add(c["page"])
                pool.append(c)
        pool.sort(key=lambda c: (c["rank"], -max(c["width"], c["height"])))
        pool = pool[:16]
        listing[cat] = [c["page_title"] for c in pool]
        frames = []
        for i, c in enumerate(pool):
            if not c.get("thumb"):
                continue
            jpg = os.path.join(out, f"{cat}-{i:02d}.jpg")
            if fetch(c["thumb"], jpg):
                lab = os.path.join(out, f"{cat}-{i:02d}-l.jpg")
                ok = run(["ffmpeg", "-y", "-loglevel", "error", "-i", jpg, "-vf",
                          "scale=320:180:force_original_aspect_ratio=increase,crop=320:180,"
                          f"drawbox=x=0:y=0:w=46:h=34:color=black@0.7:t=fill,"
                          f"drawtext=fontfile={font}:text='{i}':x=8:y=6:fontsize=24:fontcolor=white", lab])
                if ok:
                    frames.append(lab)
        if frames:
            args = ["ffmpeg", "-y", "-loglevel", "error"]
            for f in frames:
                args += ["-i", f]
            n = len(frames)
            pads = "".join(f"[{k}:v]" for k in range(n))
            cols = 4
            rows = (n + cols - 1) // cols
            layout = "|".join(f"{(k % cols) * 320}_{(k // cols) * 180}" for k in range(n))
            args += ["-filter_complex", f"{pads}xstack=inputs={n}:layout={layout}:fill=black", "-frames:v", "1",
                     os.path.join(out, f"sheet-{cat}.jpg")] if n > 1 else ["-frames:v", "1", os.path.join(out, f"sheet-{cat}.jpg")]
            run(args)
            _ = rows
        print(f"[{cat}] {len(frames)} candidates", flush=True)
    with open(os.path.join(out, "candidates.json"), "w") as f:
        json.dump(listing, f, ensure_ascii=False, indent=1)


def curated_pool(cat, titles):
    """Looks up curated file pages by title."""
    out = []
    for t in titles:
        data = api({
            "action": "query", "titles": t, "prop": "videoinfo",
            "viprop": "url|size|mime|mediatype|extmetadata|derivatives",
            "viextmetadatafilter": "LicenseShortName|Artist|ObjectName",
        })
        for p in (data.get("query") or {}).get("pages") or []:
            info = (p.get("videoinfo") or [None])[0]
            if not info:
                continue
            meta = info.get("extmetadata") or {}
            lic = clean((meta.get("LicenseShortName") or {}).get("value", ""))
            if not lic.lower().startswith(OK_LICENSES):
                print("skipping (licence)", t, lic, flush=True)
                continue
            title = p.get("title", "")
            out.append({
                "title": clean((meta.get("ObjectName") or {}).get("value", "")) or title.replace("File:", ""),
                "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
                "author": clean((meta.get("Artist") or {}).get("value", "")) or "Unknown",
                "license": lic, "url": info.get("url"), "width": info.get("width") or 0,
                "height": info.get("height") or 0, "duration": float(info.get("duration") or 0),
                "size": info.get("size") or 0, "derivatives": info.get("derivatives") or [], "rank": 0,
            })
    return out


def pexels_pool(cat, queries, key, used):
    """Stock clips from the Pexels API (needs the repository secret PEXELS_API_KEY)."""
    out = []
    for q in queries:
        url = "https://api.pexels.com/videos/search?" + urllib.parse.urlencode(
            {"query": q, "per_page": 15, "orientation": "portrait", "size": "medium"})
        try:
            req = urllib.request.Request(url, headers={"Authorization": key, "User-Agent": UA})
            with urllib.request.urlopen(req, timeout=40) as r:
                data = json.load(r)
        except Exception as e:  # noqa: BLE001
            print("pexels error", q, e, flush=True)
            continue
        for v in data.get("videos") or []:
            page = v.get("url") or ""
            if page in used or not (5 <= (v.get("duration") or 0) <= 60):
                continue
            files = [f for f in v.get("video_files") or [] if f.get("file_type") == "video/mp4" and f.get("link")]
            # The file closest to 1080 px on its short side.
            files.sort(key=lambda f: abs(min(f.get("width") or 0, f.get("height") or 0) - 1080))
            if not files:
                continue
            user = (v.get("user") or {}).get("name") or "Pexels"
            slug = page.rstrip("/").split("/")[-1]
            title = " ".join(w for w in slug.split("-")[:-1]).strip().capitalize() or q.capitalize()
            if BLOCK.search(title):
                continue
            used.add(page)
            out.append({
                "title": title, "page": page, "author": user, "license": "Pexels License",
                "url": files[0]["link"], "width": v.get("width") or 0, "height": v.get("height") or 0,
                "duration": float(v.get("duration") or 0), "size": 0, "derivatives": [], "rank": 0,
            })
            break  # one per query keeps the set varied
        time.sleep(0.4)
    return out[:VIDEOS_PER_CATEGORY]


def main():
    if sys.argv[1] == "candidates":
        candidates(sys.argv[2])
        return
    out = sys.argv[1]
    curated_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "curated.json")
    curated = json.load(open(curated_path)) if os.path.exists(curated_path) else {}
    os.makedirs(out, exist_ok=True)
    manifest = {"version": 1, "built": time.strftime("%Y-%m-%d"), "videos": [], "music": []}
    used = set()

    pexels_key = os.environ.get("PEXELS_API_KEY", "").strip()
    for cat, queries in VIDEO_QUERIES.items():
        picked = pexels_pool(cat, queries, pexels_key, used) if pexels_key else []
        if not picked and cat in curated:
            picked = curated_pool(cat, curated[cat])
        if picked:
            n = 0
            for c in picked:
                name = f"{cat}-{n + 1}.mp4"
                path = os.path.join(out, name)
                print(f"[{cat}] {c['title']} ({c['license']})", flush=True)
                if not make_clip(c, path):
                    continue
                w, h, d = probe(path)
                if d < 2 or w == 0:
                    os.remove(path)
                    continue
                manifest["videos"].append({
                    "id": name[:-4], "category": cat, "file": name, "width": w, "height": h,
                    "duration": round(d, 2), "title": c["title"], "author": c["author"],
                    "license": c["license"], "source": c["page"],
                })
                n += 1
            print(f"[{cat}] {n} curated clips", flush=True)
            continue
        # Footage is only published after a person has reviewed the candidate sheets.
        continue
        pool = []
        for q in queries:
            for src in SOURCES:
                found = search(q, "video", src)
                print(f"  search '{q}' {src or 'any'}: {len(found)}", flush=True)
                for c in found:
                    if c["page"] in used or c["width"] < 900 and c["height"] < 900:
                        continue
                    if c["duration"] and (c["duration"] < 4 or c["duration"] > 600):
                        continue
                    c["query"] = q
                    pool.append(c)
                if sum(1 for c in pool if c["query"] == q and c["rank"] < 2) >= 3:
                    break
        # One per query first (variety), CC0 first, larger frames first.
        pool.sort(key=lambda c: (c["rank"], -max(c["width"], c["height"])))
        picked, seen_q = [], set()
        for c in pool:
            if c["query"] not in seen_q and c["page"] not in used:
                picked.append(c); seen_q.add(c["query"]); used.add(c["page"])
        for c in pool:
            if len(picked) >= VIDEOS_PER_CATEGORY + 2:
                break
            if c["page"] not in used:
                picked.append(c); used.add(c["page"])
        # General Commons results (rank 2+) are only a fallback when stock sources are thin.
        stock = [c for c in picked if c["rank"] < 2]
        if len(stock) >= VIDEOS_PER_CATEGORY:
            picked = stock + [c for c in picked if c["rank"] >= 2]
        n = 0
        for c in picked:
            if n >= VIDEOS_PER_CATEGORY:
                break
            name = f"{cat}-{n + 1}.mp4"
            path = os.path.join(out, name)
            print(f"[{cat}] {c['title']} ({c['license']})", flush=True)
            if not make_clip(c, path):
                continue
            w, h, d = probe(path)
            if d < 2 or w == 0:
                os.remove(path)
                continue
            manifest["videos"].append({
                "id": name[:-4], "category": cat, "file": name, "width": w, "height": h,
                "duration": round(d, 2), "title": c["title"], "author": c["author"],
                "license": c["license"], "source": c["page"],
            })
            n += 1
        print(f"[{cat}] {n} clips", flush=True)

    for genre, queries in MUSIC_QUERIES.items():
        pool = []
        for q in queries:
            for c in search(q, "audio"):
                if c["page"] in used or not (45 <= (c["duration"] or 0) <= 400):
                    continue
                pool.append(c)
        pool.sort(key=lambda c: (c["rank"], -c["duration"]))
        n = 0
        for c in pool:
            if n >= TRACKS_PER_GENRE:
                break
            if c["page"] in used:
                continue
            used.add(c["page"])
            name = f"music-{genre.lower()}-{n + 1}.m4a"
            path = os.path.join(out, name)
            print(f"[music {genre}] {c['title']} ({c['license']})", flush=True)
            if not make_track(c, path):
                continue
            _, _, d = probe(path)
            if d < 20:
                os.remove(path)
                continue
            manifest["music"].append({
                "id": name[:-4], "genre": genre, "file": name, "duration": round(d, 2),
                "title": c["title"], "author": c["author"], "license": c["license"], "source": c["page"],
            })
            n += 1

    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("videos", len(manifest["videos"]), "music", len(manifest["music"]), flush=True)


if __name__ == "__main__":
    main()
