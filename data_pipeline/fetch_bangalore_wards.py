import urllib.request
import urllib.parse
import json
import time

def fetch(query):
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request("https://overpass-api.de/api/interpreter", data=data)
    req.add_header("User-Agent", "SpatialAnchorMap/1.0")
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode()
        if not raw.strip():
            raise ValueError("Empty")
        return json.loads(raw)

def assemble_rings(members):
    outer_ways = []
    for m in members:
        if m.get("role") == "outer" and "geometry" in m:
            coords = [[p["lon"], p["lat"]] for p in m["geometry"]]
            if len(coords) >= 2:
                outer_ways.append(coords)
    if not outer_ways:
        return []
    completed = []
    remaining = [list(w) for w in outer_ways]
    while remaining:
        ring = list(remaining.pop(0))
        changed = True
        while changed:
            changed = False
            for i in range(len(remaining)):
                way = remaining[i]
                if abs(way[0][0]-ring[-1][0])<0.00001 and abs(way[0][1]-ring[-1][1])<0.00001:
                    ring.extend(way[1:]); remaining.pop(i); changed = True; break
                elif abs(way[-1][0]-ring[-1][0])<0.00001 and abs(way[-1][1]-ring[-1][1])<0.00001:
                    ring.extend(list(reversed(way))[1:]); remaining.pop(i); changed = True; break
                elif abs(way[-1][0]-ring[0][0])<0.00001 and abs(way[-1][1]-ring[0][1])<0.00001:
                    ring = way + ring[1:]; remaining.pop(i); changed = True; break
                elif abs(way[0][0]-ring[0][0])<0.00001 and abs(way[0][1]-ring[0][1])<0.00001:
                    ring = list(reversed(way)) + ring[1:]; remaining.pop(i); changed = True; break
        if len(ring) >= 4:
            if ring[0] != ring[-1]:
                ring.append(ring[0])
            completed.append(ring)
    return completed

def build_features(osm):
    features = []
    for el in osm["elements"]:
        if el["type"] != "relation":
            continue
        tags = el.get("tags", {})
        name = tags.get("name:en") or tags.get("name") or "Unknown"
        rings = assemble_rings(el.get("members", []))
        if not rings:
            continue
        if len(rings) == 1:
            geometry = {"type": "Polygon", "coordinates": [rings[0]]}
        else:
            geometry = {"type": "MultiPolygon", "coordinates": [[r] for r in rings]}
        features.append({
            "type": "Feature",
            "properties": {
                "district": None,
                "mandal": None,
                "village": name,
            },
            "geometry": geometry
        })
    return features

assets = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/assets/data"

# Level 9 — BBMP wards (Marathalli, Bellandur etc.)
print("Fetching Bangalore level 9 (BBMP wards)...")
q9 = '[out:json][timeout:120];\narea["name"="Bengaluru Urban"]["admin_level"="5"]->.b;\nrel(area.b)["admin_level"="9"]["boundary"="administrative"];\nout geom;'
osm9 = fetch(q9)
feats9 = build_features(osm9)
print(f"  Got {len(feats9)} ward boundaries")
time.sleep(5)

# Level 10 — revenue villages
print("Fetching Bangalore level 10 (revenue villages)...")
q10 = '[out:json][timeout:120];\narea["name"="Bengaluru Urban"]["admin_level"="5"]->.b;\nrel(area.b)["admin_level"="10"]["boundary"="administrative"];\nout geom;'
osm10 = fetch(q10)
feats10 = build_features(osm10)
print(f"  Got {len(feats10)} revenue village boundaries")
time.sleep(5)

# Karnataka-wide level 9
print("Fetching Karnataka-wide level 9...")
q9k = '[out:json][timeout:120];\narea["name"="Karnataka"]["admin_level"="4"]->.k;\nrel(area.k)["admin_level"="9"]["boundary"="administrative"];\nout geom;'
try:
    osm9k = fetch(q9k)
    feats9k = build_features(osm9k)
    print(f"  Got {len(feats9k)} Karnataka level-9 boundaries")
except Exception as e:
    feats9k = []
    print(f"  Failed: {e}")

all_new = feats9 + feats10 + feats9k
print(f"\nTotal new village/ward boundaries: {len(all_new)}")

with open(f"{assets}/india_boundaries.geojson") as f:
    existing = json.load(f)

combined = {
    "type": "FeatureCollection",
    "features": existing["features"] + all_new
}

with open(f"{assets}/india_boundaries.geojson", "w") as f:
    json.dump(combined, f)
with open(f"{assets}/india_detection.geojson", "w") as f:
    json.dump(combined, f)

print(f"Total features in file: {len(combined['features'])}")
print("Done!")
