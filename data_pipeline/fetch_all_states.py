import urllib.request
import urllib.parse
import json
import time
import os

OUTPUT_DIR = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/data_pipeline/state_files"
ASSETS_DIR = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/assets/data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# All Indian states with their OSM names and bounding boxes
STATES = [
    {"id": "andhra_pradesh",    "name": "Andhra Pradesh",       "osm": "Andhra Pradesh",       "bbox": (12.6, 76.8, 19.9, 84.8)},
    {"id": "arunachal_pradesh", "name": "Arunachal Pradesh",    "osm": "Arunachal Pradesh",    "bbox": (26.6, 91.5, 29.5, 97.4)},
    {"id": "assam",             "name": "Assam",                "osm": "Assam",                "bbox": (24.1, 89.7, 27.9, 96.0)},
    {"id": "bihar",             "name": "Bihar",                "osm": "Bihar",                "bbox": (24.3, 83.3, 27.5, 88.3)},
    {"id": "chhattisgarh",      "name": "Chhattisgarh",         "osm": "Chhattisgarh",         "bbox": (17.8, 80.3, 24.1, 84.4)},
    {"id": "goa",               "name": "Goa",                  "osm": "Goa",                  "bbox": (14.9, 73.6, 15.8, 74.4)},
    {"id": "gujarat",           "name": "Gujarat",              "osm": "Gujarat",              "bbox": (20.1, 68.2, 24.7, 74.5)},
    {"id": "haryana",           "name": "Haryana",              "osm": "Haryana",              "bbox": (27.6, 74.5, 30.9, 77.6)},
    {"id": "himachal_pradesh",  "name": "Himachal Pradesh",     "osm": "Himachal Pradesh",     "bbox": (30.4, 75.6, 33.2, 79.0)},
    {"id": "jharkhand",         "name": "Jharkhand",            "osm": "Jharkhand",            "bbox": (21.9, 83.3, 25.4, 87.5)},
    {"id": "karnataka",         "name": "Karnataka",            "osm": "Karnataka",            "bbox": (11.5, 74.0, 18.5, 78.6)},
    {"id": "kerala",            "name": "Kerala",               "osm": "Kerala",               "bbox": (8.2,  74.8, 12.8, 77.4)},
    {"id": "madhya_pradesh",    "name": "Madhya Pradesh",       "osm": "Madhya Pradesh",       "bbox": (21.1, 74.0, 26.9, 82.8)},
    {"id": "maharashtra",       "name": "Maharashtra",          "osm": "Maharashtra",          "bbox": (15.6, 72.6, 22.1, 80.9)},
    {"id": "manipur",           "name": "Manipur",              "osm": "Manipur",              "bbox": (23.8, 93.0, 25.7, 94.8)},
    {"id": "meghalaya",         "name": "Meghalaya",            "osm": "Meghalaya",            "bbox": (25.0, 89.8, 26.1, 92.8)},
    {"id": "mizoram",           "name": "Mizoram",              "osm": "Mizoram",              "bbox": (21.9, 92.2, 24.5, 93.4)},
    {"id": "nagaland",          "name": "Nagaland",             "osm": "Nagaland",             "bbox": (25.1, 93.3, 27.1, 95.3)},
    {"id": "odisha",            "name": "Odisha",               "osm": "Odisha",               "bbox": (17.8, 81.4, 22.6, 87.5)},
    {"id": "punjab",            "name": "Punjab",               "osm": "Punjab",               "bbox": (29.5, 73.9, 32.6, 76.9)},
    {"id": "rajasthan",         "name": "Rajasthan",            "osm": "Rajasthan",            "bbox": (23.0, 69.5, 30.2, 78.3)},
    {"id": "sikkim",            "name": "Sikkim",               "osm": "Sikkim",               "bbox": (27.0, 88.0, 28.2, 88.9)},
    {"id": "tamil_nadu",        "name": "Tamil Nadu",           "osm": "Tamil Nadu",           "bbox": (8.0,  76.2, 13.6, 80.4)},
    {"id": "telangana",         "name": "Telangana",            "osm": "Telangana",            "bbox": (15.8, 77.0, 19.9, 81.5)},
    {"id": "tripura",           "name": "Tripura",              "osm": "Tripura",              "bbox": (22.9, 91.1, 24.5, 92.3)},
    {"id": "uttar_pradesh",     "name": "Uttar Pradesh",        "osm": "Uttar Pradesh",        "bbox": (23.9, 77.1, 30.4, 84.7)},
    {"id": "uttarakhand",       "name": "Uttarakhand",          "osm": "Uttarakhand",          "bbox": (28.7, 78.0, 31.5, 81.1)},
    {"id": "west_bengal",       "name": "West Bengal",          "osm": "West Bengal",          "bbox": (21.5, 85.8, 27.2, 89.9)},
    # Union Territories
    {"id": "delhi",             "name": "Delhi",                "osm": "Delhi",                "bbox": (28.4, 76.8, 28.9, 77.4)},
    {"id": "jammu_kashmir",     "name": "Jammu & Kashmir",      "osm": "Jammu and Kashmir",    "bbox": (32.3, 73.7, 37.1, 80.4)},
    {"id": "ladakh",            "name": "Ladakh",               "osm": "Ladakh",               "bbox": (32.0, 75.0, 36.0, 80.0)},
    {"id": "puducherry",        "name": "Puducherry",           "osm": "Puducherry",           "bbox": (10.6, 79.5, 12.1, 80.2)},
    {"id": "chandigarh",        "name": "Chandigarh",           "osm": "Chandigarh",           "bbox": (30.6, 76.6, 30.8, 76.9)},
]

def fetch(query, server="https://overpass-api.de/api/interpreter", timeout=90):
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(server, data=data)
    req.add_header("User-Agent", "SpatialAnchorMap/1.0")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode()
        if not raw.strip():
            raise ValueError("Empty response")
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

def build_features(osm, is_district=False, is_mandal=False, is_village=False):
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
                "village": name if is_village else None,
            },
            "geometry": geometry
        })
    return features

def fetch_villages_bbox(s, w, n, e):
    """Fetch village points in a bounding box"""
    query = f'[out:json][timeout:30];\n(node["place"~"village|hamlet|town|suburb"]({s},{w},{n},{e}););\nout body;'
    try:
        osm = fetch(query, timeout=40)
        features = []
        for el in osm["elements"]:
            tags = el.get("tags", {})
            name = tags.get("name") or tags.get("name:en")
            if not name:
                continue
            features.append({
                "type": "Feature",
                "properties": {"district": None, "mandal": None, "village": name},
                "geometry": {"type": "Point", "coordinates": [el["lon"], el["lat"]]}
            })
        return features
    except Exception as e:
        print(f"      bbox failed: {e}")
        return []

def process_state(state):
    state_id = state["id"]
    state_name = state["name"]
    osm_name = state["osm"]
    s, w, n, e = state["bbox"]

    print(f"\n{'='*50}")
    print(f"Processing: {state_name}")
    print(f"{'='*50}")

    all_features = []

    # 1. Districts (admin_level 5)
    print(f"  Fetching districts...")
    for attempt in range(2):
        try:
            q = f'[out:json][timeout:60];\narea["name"="{osm_name}"]["admin_level"="4"]->.s;\nrel(area.s)["admin_level"="5"]["boundary"="administrative"];\nout geom;'
            osm = fetch(q, timeout=70)
            feats = build_features(osm, is_district=True)
            all_features.extend(feats)
            print(f"  Districts: {len(feats)}")
            break
        except Exception as ex:
            print(f"  District attempt {attempt+1} failed: {ex}")
            time.sleep(5)

    time.sleep(3)

    # 2. Mandals/Taluks (admin_level 6)
    print(f"  Fetching mandals/taluks...")
    for attempt in range(2):
        try:
            q = f'[out:json][timeout:90];\narea["name"="{osm_name}"]["admin_level"="4"]->.s;\nrel(area.s)["admin_level"="6"]["boundary"="administrative"];\nout geom;'
            osm = fetch(q, timeout=100)
            feats = build_features(osm, is_mandal=True)
            all_features.extend(feats)
            print(f"  Mandals: {len(feats)}")
            break
        except Exception as ex:
            print(f"  Mandal attempt {attempt+1} failed: {ex}")
            time.sleep(5)

    time.sleep(3)

    # 3. Sub-district boundaries (admin_level 8, 9, 10 — for cities)
    for level in [8, 9, 10]:
        try:
            q = f'[out:json][timeout:30];\narea["name"="{osm_name}"]["admin_level"="4"]->.s;\nrel(area.s)["admin_level"="{level}"]["boundary"="administrative"];\nout tags;'
            osm = fetch(q, timeout=35)
            count = len([e for e in osm["elements"] if e["type"] == "relation"])
            if count > 0 and count < 2000:
                print(f"  Fetching level {level} ({count} boundaries)...")
                q2 = f'[out:json][timeout:60];\narea["name"="{osm_name}"]["admin_level"="4"]->.s;\nrel(area.s)["admin_level"="{level}"]["boundary"="administrative"];\nout geom;'
                osm2 = fetch(q2, timeout=70)
                feats = build_features(osm2, is_village=True)
                all_features.extend(feats)
                print(f"  Level {level}: {len(feats)}")
                time.sleep(3)
        except Exception as ex:
            print(f"  Level {level} failed: {ex}")
        time.sleep(2)

    # 4. Village points in chunks
    print(f"  Fetching village points...")
    seen = set()
    lat_step = 1.0
    lng_step = 1.0
    lat = s
    village_count = 0
    while lat < n:
        lng = w
        while lng < e:
            time.sleep(1)
            feats = fetch_villages_bbox(lat, lng, min(lat+lat_step, n), min(lng+lng_step, e))
            for feat in feats:
                c = feat["geometry"]["coordinates"]
                key = f"{c[1]:.4f}_{c[0]:.4f}"
                if key not in seen:
                    seen.add(key)
                    all_features.append(feat)
                    village_count += 1
            lng += lng_step
        lat += lat_step
    print(f"  Villages: {village_count}")

    # Save state file
    geojson = {"type": "FeatureCollection", "features": all_features}
    filepath = f"{OUTPUT_DIR}/{state_id}.geojson"
    with open(filepath, "w") as f:
        json.dump(geojson, f)

    size_mb = os.path.getsize(filepath) / (1024 * 1024)
    print(f"  SAVED: {len(all_features)} features, {size_mb:.1f} MB")
    return {
        "id": state_id,
        "name": state_name,
        "filename": f"{state_id}.geojson",
        "feature_count": len(all_features),
        "size_mb": round(size_mb, 1)
    }

# Skip already processed states
existing_ids = set()
manifest_path = f"{OUTPUT_DIR}/manifest.json"
if os.path.exists(manifest_path):
    with open(manifest_path) as f:
        existing = json.load(f)
    existing_ids = {s["id"] for s in existing}
    manifest = existing
    print(f"Already processed: {existing_ids}")
else:
    manifest = []

# Process remaining states
for state in STATES:
    if state["id"] in existing_ids:
        print(f"Skipping {state['name']} (already done)")
        continue
    try:
        result = process_state(state)
        manifest.append(result)
        # Save manifest after each state
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
        print(f"Manifest updated ({len(manifest)} states)")
    except Exception as ex:
        print(f"FAILED {state['name']}: {ex}")
    time.sleep(5)

# Copy manifest to assets
import shutil
shutil.copy(manifest_path, f"{ASSETS_DIR}/manifest.json")
print(f"\n✅ Done! {len(manifest)} states processed")
print(f"Manifest copied to assets")
