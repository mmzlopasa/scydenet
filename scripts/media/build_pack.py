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
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "SCYDE-media-pack/1.0 (https://scyde.dev; https://github.com/mmzlopasa/scydenet)"
OK_LICENSES = ("cc0", "public domain", "pd", "cc by 4.0", "cc by 3.0", "cc by 2.5", "cc by 2.0")
BLOCK = re.compile(r"nude|naked|sex|porn|erotic|blood|corpse|dead|war\b|weapon|gun|execution|nazi|riot|accident|crash|injur|surgery|autopsy|hunting|slaughter", re.I)

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


def search(query, kind):
    data = api({
        "action": "query",
        "generator": "search",
        "gsrnamespace": 6,
        "gsrsearch": f"{query} filetype:{kind}",
        "gsrlimit": 40,
        "prop": "videoinfo",
        "viprop": "url|size|mime|mediatype|extmetadata|derivatives",
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
            "width": info.get("width") or 0,
            "height": info.get("height") or 0,
            "duration": float(info.get("duration") or 0),
            "size": info.get("size") or 0,
            "derivatives": info.get("derivatives") or [],
            "rank": 0 if lic.lower().startswith(("cc0", "public domain", "pd")) else 1,
        })
    return out


def best_video_source(c):
    """A derivative around 720p if there is one (small download), else the original."""
    good = [d for d in c["derivatives"] if d.get("src") and 480 <= int(d.get("height") or 0) <= 1080]
    good.sort(key=lambda d: abs(int(d.get("height") or 0) - 720))
    if good:
        return good[0]["src"]
    return c["url"]


def run(cmd, timeout=240):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if r.returncode != 0:
            print("ffmpeg failed:", r.stderr[-400:], flush=True)
        return r.returncode == 0
    except subprocess.TimeoutExpired:
        print("ffmpeg timeout", flush=True)
        return False


def make_clip(c, out_path):
    src = best_video_source(c)
    dur = c["duration"] or 12
    start = max(0.0, min(dur * 0.25, dur - 6)) if dur > 7 else 0
    vf = ("scale=w='if(gt(iw,ih),960,-2)':h='if(gt(iw,ih),-2,960)',"
          "fps=30,format=yuv420p")
    return run(["ffmpeg", "-y", "-loglevel", "error", "-user_agent", UA, "-ss", f"{start:.2f}", "-i", src,
                "-t", "5", "-an", "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "25",
                "-movflags", "+faststart", out_path])


def make_track(c, out_path):
    return run(["ffmpeg", "-y", "-loglevel", "error", "-user_agent", UA, "-i", c["url"], "-t", "90",
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


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {"version": 1, "built": time.strftime("%Y-%m-%d"), "videos": [], "music": []}
    used = set()

    for cat, queries in VIDEO_QUERIES.items():
        pool = []
        for q in queries:
            for c in search(q, "video"):
                if c["page"] in used or c["width"] < 900 and c["height"] < 900:
                    continue
                if c["duration"] and c["duration"] < 4:
                    continue
                c["query"] = q
                pool.append(c)
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
