import json
import os

assets = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/assets/data"
output_dir = "/Users/harishreddythalla/HMaps Claude/spatial_anchor_map/data_pipeline/state_files"
os.makedirs(output_dir, exist_ok=True)

# Load all data
with open(f"{assets}/india_boundaries.geojson") as f:
    data = json.load(f)

with open(f"{assets}/india_states.geojson") as f:
    states_data = json.load(f)

features = data["features"]

print(f"Total features: {len(features)}")

# Define state bounding boxes for spatial filtering
state_bboxes = {
    "telangana": (15.8, 77.0, 19.9, 81.5),
    "karnataka": (11.5, 74.0, 18.5, 78.6),
    "andhra_pradesh": (12.6, 76.8, 19.9, 84.8),
    "maharashtra": (15.6, 72.6, 22.1, 80.9),
    "tamil_nadu": (8.0, 76.2, 13.6, 80.4),
    "kerala": (8.2, 74.8, 12.8, 77.4),
    "goa": (14.9, 73.6, 15.8, 74.4),
    "gujarat": (20.1, 68.2, 24.7, 74.5),
    "rajasthan": (23.0, 69.5, 30.2, 78.3),
    "madhya_pradesh": (21.1, 74.0, 26.9, 82.8),
    "uttar_pradesh": (23.9, 77.1, 30.4, 84.7),
    "bihar": (24.3, 83.3, 27.5, 88.3),
    "west_bengal": (21.5, 85.8, 27.2, 89.9),
    "odisha": (17.8, 81.4, 22.6, 87.5),
    "chhattisgarh": (17.8, 80.3, 24.1, 84.4),
    "jharkhand": (21.9, 83.3, 25.4, 87.5),
    "assam": (24.1, 89.7, 27.9, 96.0),
    "punjab": (29.5, 73.9, 32.6, 76.9),
    "haryana": (27.6, 74.5, 30.9, 77.6),
    "himachal_pradesh": (30.4, 75.6, 33.2, 79.0),
    "uttarakhand": (28.7, 78.0, 31.5, 81.1),
    "delhi": (28.4, 76.8, 28.9, 77.4),
}

state_display_names = {
    "telangana": "Telangana",
    "karnataka": "Karnataka",
    "andhra_pradesh": "Andhra Pradesh",
    "maharashtra": "Maharashtra",
    "tamil_nadu": "Tamil Nadu",
    "kerala": "Kerala",
    "goa": "Goa",
    "gujarat": "Gujarat",
    "rajasthan": "Rajasthan",
    "madhya_pradesh": "Madhya Pradesh",
    "uttar_pradesh": "Uttar Pradesh",
    "bihar": "Bihar",
    "west_bengal": "West Bengal",
    "odisha": "Odisha",
    "chhattisgarh": "Chhattisgarh",
    "jharkhand": "Jharkhand",
    "assam": "Assam",
    "punjab": "Punjab",
    "haryana": "Haryana",
    "himachal_pradesh": "Himachal Pradesh",
    "uttarakhand": "Uttarakhand",
    "delhi": "Delhi",
}

def get_centroid(feature):
    """Get approximate centroid of a feature"""
    geom = feature.get("geometry", {})
    gtype = geom.get("type", "")
    coords = geom.get("coordinates", [])

    try:
        if gtype == "Point":
            return coords[1], coords[0]
        elif gtype == "Polygon" and coords:
            ring = coords[0]
            lats = [c[1] for c in ring]
            lngs = [c[0] for c in ring]
            return sum(lats)/len(lats), sum(lngs)/len(lngs)
        elif gtype == "MultiPolygon" and coords:
            ring = coords[0][0]
            lats = [c[1] for c in ring]
            lngs = [c[0] for c in ring]
            return sum(lats)/len(lats), sum(lngs)/len(lngs)
    except:
        pass
    return None, None

def in_bbox(lat, lng, bbox):
    s, w, n, e = bbox
    return s <= lat <= n and w <= lng <= e

# Split features by state
state_features = {state: [] for state in state_bboxes}

for feat in features:
    lat, lng = get_centroid(feat)
    if lat is None:
        continue
    for state, bbox in state_bboxes.items():
        if in_bbox(lat, lng, bbox):
            state_features[state].append(feat)
            break  # assign to first matching state only

# Also add state boundary itself to each file
state_boundaries = {}
for sf in states_data["features"]:
    name = sf["properties"].get("state", "").lower()
    for state_key in state_bboxes:
        display = state_display_names[state_key].lower()
        if display in name or name in display:
            state_boundaries[state_key] = sf
            break

# Save per-state files
manifest = []
for state, feats in state_features.items():
    if not feats:
        continue

    # Add state boundary polygon
    if state in state_boundaries:
        feats = [state_boundaries[state]] + feats

    geojson = {"type": "FeatureCollection", "features": feats}
    filename = f"{state}.geojson"
    filepath = f"{output_dir}/{filename}"

    with open(filepath, "w") as f:
        json.dump(geojson, f)

    size_mb = os.path.getsize(filepath) / (1024 * 1024)
    print(f"{state_display_names[state]}: {len(feats)} features, {size_mb:.1f} MB -> {filename}")

    manifest.append({
        "id": state,
        "name": state_display_names[state],
        "filename": filename,
        "feature_count": len(feats),
        "size_mb": round(size_mb, 1)
    })

# Save manifest
with open(f"{output_dir}/manifest.json", "w") as f:
    json.dump(manifest, f, indent=2)

print(f"\nManifest saved. {len(manifest)} states ready.")
print(f"Files at: {output_dir}")
print("\nNext: Upload these files to GitHub Releases")
print("Repo URL format: https://github.com/YOUR_USERNAME/spatial-anchor-data/releases/download/v1.0/STATE.geojson")
