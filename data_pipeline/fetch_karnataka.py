import urllib.request
import urllib.parse
import json
import time

def assemble_rings(members):
    outer_ways = []
    for m in members:
        if m.get("role") == "outer" and "geometry" in m:
            coords = [[p["lon"], p["lat"]] for p in m["geometry"]]
            if len(coords) >= 2:
                outer_ways.append(coords)
    if not outer_ways:
        return []
    completed_rings = []
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
            completed_rings.append(ring)
    return completed_rings

def fetch(query, server="https://overpass.kumi.systems/api/interpreter"):
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(server, data=data)
    req.add_header("User-Agent", "SpatialAnchorMap/1.0")
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode()
        if not raw.strip():
            raise ValueError("Empty response")
        return json.loads(raw)

def build_geojson(osm, is_district, is_mandal):
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
                "district": name if is_district else None,
                "mandal": name if is_mandal else None,
                "village": None,
            },
            "geometry": geometry
        })
    return features

# ── Fetch Karnataka Districts (admin_level 5) ─────────────────────────────────
print("Fetching Karnataka districts...")
dist_osm = fetch("""
[out:json][timeout:90];
area["name"="Karnataka"]["admin_level"="4"]->.k;
rel(area.k)["admin_level"="5"]["boundary"="administrative"];
out geom;
""")
dist_features = build_geojson(dist_osm, True, False)
print(f"  Got {len(dist_features)} districts")
time.sleep(4)

# ── Fetch Karnataka Taluks (admin_level 6) ────────────────────────────────────
print("Fetching Karnataka taluks/mandals...")
taluk_osm = fetch("""
[out:json][timeout:180];
area["name"="Karnataka"]["admin_level"="4"]->.k;
rel(area.k)["admin_level"="6"]["boundary"="administrative"];
out geom;
""")
taluk_features = build_geojson(taluk_osm, False, True)
print(f"  Got {len(taluk_features)} taluks")
time.sleep(5)

# ── Fetch Karnataka Villages (bbox chunks) ────────────────────────────────────
print("Fetching Karnataka villages...")
# Karnataka bbox: 11.5-18.5 lat, 74.0-78.5 lng split into small chunks
bboxes = []
lats = [(l/10, l/10 + 0.5) for l in range(115, 185, 5)]
lngs = [(l/10, l/10 + 0.5) for l in range(740, 785, 5)]
for s, n in lats:
    for w, e in lngs:
        bboxes.append((s, w, n, e))

village_features = []
seen = set()

for i, (s, w, n, e) in enumerate(bboxes):
    try:
        query = f"""
[out:json][timeout:30];
(node["place"~"village|hamlet|town|suburb|neighbourhood"]({s},{w},{n},{e}););
out body;
"""
        osm = fetch(query)
        count = 0
        for el in osm["elements"]:
            tags = el.get("tags", {})
            name = tags.get("name") or tags.get("name:en")
            if not name:
                continue
            key = f"{el['lat']:.4f}_{el['lon']:.4f}"
            if key in seen:
                continue
            seen.add(key)
            village_features.append({
                "type": "Feature",
                "properties": {
                    "district": None,
                    "mandal": None,
                    "village": name,
                    "place_type": tags.get("place", "village")
                },
                "geometry": {
                    "type": "Point",
                    "coordinates": [el["lon"], el["lat"]]
                }
            })
            count += 1
        if count > 0:
            print(f"  Chunk {i+1}/{len(bboxes)} ({s},{w}): +{count}")
    except Exception as ex:
        print(f"  Chunk {i+1}/{len(bboxes)} ({s},{w}): failed - {ex}")
    time.sleep(1)

print(f"  Total Karnataka villages: {len(village_features)}")

# ── Merge with existing data ──────────────────────────────────────────────────
print("Merging with existing Telangana data...")

assets_path = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/assets/data"

with open(f"{assets_path}/india_boundaries.geojson") as f:
    existing = json.load(f)

karnataka_features = dist_features + taluk_features + village_features
combined = {
    "type": "FeatureCollection",
    "features": existing["features"] + karnataka_features
}

with open(f"{assets_path}/india_boundaries.geojson", "w") as f:
    json.dump(combined, f)
with open(f"{assets_path}/india_detection.geojson", "w") as f:
    json.dump(combined, f)

print(f"\nKarnataka added: {len(karnataka_features)} features")
print(f"  - Districts: {len(dist_features)}")
print(f"  - Taluks: {len(taluk_features)}")
print(f"  - Villages: {len(village_features)}")
print(f"Total features in file: {len(combined['features'])}")
print("Done!")
