#!/usr/bin/env python3
"""
Fetch village boundary polygons from open data sources and merge into
existing state GeoJSON files (replacing point-only village markers).

Sources:
  - Karnataka: DataMeet Indian Village Boundaries (ka/ka.geojson)
    https://github.com/datameet/indian_village_boundaries
    License: ODbL

  - Telangana: Govt Tank Information System boundaries
    https://github.com/gggodhwani/telangana_boundaries
    License: MIT

  - Other states: ramSeraph/indian_admin_boundaries LGD data
    https://github.com/ramSeraph/indian_admin_boundaries
    License: CC0 1.0 (requires py7zr — install with: pip3 install py7zr)

Usage:
  python3 fetch_lgd_villages.py telangana
  python3 fetch_lgd_villages.py karnataka
  python3 fetch_lgd_villages.py all
"""

import json
import lzma
import os
import sys
import tempfile
import time
import urllib.request

PIPELINE_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILES_DIR = os.path.join(PIPELINE_DIR, "state_files")

# ── Data Sources ──────────────────────────────────────────────────────

KARNATAKA_URL = (
    "https://raw.githubusercontent.com/datameet/"
    "indian_village_boundaries/master/ka/ka.geojson"
)

TELANGANA_URL = (
    "https://github.com/gggodhwani/telangana_boundaries/"
    "raw/master/village_boundaries.json.xz"
)


def download(url, label=""):
    """Download a URL and return bytes."""
    print(f"    Downloading {label or url}...")
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "SpatialAnchorMap/1.0")
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = resp.read()
    print(f"    Downloaded {len(data) / 1024 / 1024:.1f} MB")
    return data


def fetch_karnataka_villages():
    """Fetch Karnataka village polygons from DataMeet."""
    raw = download(KARNATAKA_URL, "DataMeet Karnataka villages")
    gj = json.loads(raw)

    features = []
    for feat in gj.get("features", []):
        geom = feat.get("geometry")
        if not geom or geom.get("type") not in ("Polygon", "MultiPolygon"):
            continue
        props = feat.get("properties", {})
        # DataMeet uses various property names
        name = (
            props.get("NAME")
            or props.get("name")
            or props.get("VILLAGE_NA")
            or props.get("village_na")
            or props.get("Village_Na")
            or "Unknown"
        )
        features.append({
            "type": "Feature",
            "properties": {"district": None, "mandal": None, "village": name},
            "geometry": geom,
        })

    print(f"    Parsed {len(features)} village polygons")
    return features


def fetch_telangana_villages():
    """Fetch Telangana village polygons (xz-compressed GeoJSON)."""
    raw_xz = download(TELANGANA_URL, "Telangana village boundaries (xz)")
    print("    Decompressing xz...")
    raw = lzma.decompress(raw_xz)
    gj = json.loads(raw)

    features = []
    for feat in gj.get("features", []):
        geom = feat.get("geometry")
        if not geom or geom.get("type") not in ("Polygon", "MultiPolygon"):
            continue
        props = feat.get("properties", {})
        name = (
            props.get("DMV_N")
            or props.get("VILLAGE_NA")
            or props.get("village_na")
            or props.get("Village_Na")
            or props.get("NAME")
            or props.get("name")
            or "Unknown"
        )
        features.append({
            "type": "Feature",
            "properties": {"district": None, "mandal": None, "village": name},
            "geometry": geom,
        })

    print(f"    Parsed {len(features)} village polygons")
    return features


# Map state_id → fetcher function
FETCHERS = {
    "karnataka": fetch_karnataka_villages,
    "telangana": fetch_telangana_villages,
}


def upgrade_state_file(state_id):
    """
    Load existing state GeoJSON, replace point-only villages with
    polygon data, and save.
    """
    filepath = os.path.join(STATE_FILES_DIR, f"{state_id}.geojson")
    if not os.path.exists(filepath):
        print(f"  ⚠ {filepath} not found, skipping")
        return False

    fetcher = FETCHERS.get(state_id)
    if not fetcher:
        print(f"  ⚠ No village polygon source for {state_id}")
        return False

    print(f"\n  Loading existing data...")
    with open(filepath) as f:
        gj = json.load(f)

    original_count = len(gj["features"])

    # Separate: keep districts + mandals + existing village polygons.
    # Remove point-only villages.
    kept = []
    removed_points = 0
    existing_village_names = set()

    for feat in gj["features"]:
        is_village = feat["properties"].get("village") is not None
        is_point = feat["geometry"]["type"] == "Point"
        if is_village and is_point:
            removed_points += 1
            continue
        if is_village:
            vname = (feat["properties"]["village"] or "").lower().strip()
            existing_village_names.add(vname)
        kept.append(feat)

    print(f"  Original: {original_count} features")
    print(f"  Removing: {removed_points} village point markers")
    print(f"  Keeping: {len(kept)} features (districts + mandals + existing polys)")

    # Fetch new polygon data
    print(f"\n  Fetching village polygons...")
    new_villages = fetcher()

    if not new_villages:
        print(f"  ⚠ No polygon data fetched, keeping original file")
        return False

    # Merge: avoid duplicates by name
    added = 0
    for feat in new_villages:
        vname = (feat["properties"].get("village") or "").lower().strip()
        if vname and vname not in existing_village_names:
            kept.append(feat)
            existing_village_names.add(vname)
            added += 1

    gj["features"] = kept
    final_count = len(kept)

    # Save
    # Back up original first
    backup = filepath + ".bak"
    if not os.path.exists(backup):
        import shutil
        shutil.copy2(filepath, backup)
        print(f"  Backup saved to {backup}")

    with open(filepath, "w") as f:
        json.dump(gj, f)

    size_mb = os.path.getsize(filepath) / (1024 * 1024)
    print(f"\n  ✓ Saved: {final_count} features ({added} new village polygons)")
    print(f"  File size: {size_mb:.1f} MB")

    # Update manifest
    manifest_path = os.path.join(STATE_FILES_DIR, "manifest.json")
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            manifest = json.load(f)
        for entry in manifest:
            if entry["id"] == state_id:
                entry["feature_count"] = final_count
                entry["size_mb"] = round(size_mb, 1)
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
        print(f"  Manifest updated")

    return True


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None

    if not target:
        print("Usage: python3 fetch_lgd_villages.py <state_id|all>")
        print(f"Available states: {', '.join(sorted(FETCHERS.keys()))}")
        sys.exit(1)

    if target == "all":
        for state_id in sorted(FETCHERS.keys()):
            print(f"\n{'=' * 50}")
            print(f"Upgrading: {state_id}")
            print(f"{'=' * 50}")
            try:
                upgrade_state_file(state_id)
            except Exception as e:
                print(f"  ✗ Failed: {e}")
                import traceback
                traceback.print_exc()
            time.sleep(2)
    else:
        print(f"\n{'=' * 50}")
        print(f"Upgrading: {target}")
        print(f"{'=' * 50}")
        upgrade_state_file(target)

    print("\n✅ Done!")
    print("Next steps:")
    print("  1. Upload updated state files to GitHub releases")
    print("  2. Rebuild APK: flutter build apk --release")
