#!/usr/bin/env bash
set -euo pipefail

# Builds vector boundary PMTiles (MVT) for the application.
#
# Requires:
# - tippecanoe (brew install tippecanoe)
# - pmtiles (npm i -g pmtiles)
# - python3 (for normalization)
#
# Usage:
#   ./data_pipeline/build_boundary_pmtiles.sh <state_id> <state_code>
#   e.g. ./data_pipeline/build_boundary_pmtiles.sh telangana TS

STATE_ID="${1:-}"
STATE_CODE="${2:-}"

if [[ -z "${STATE_ID}" || -z "${STATE_CODE}" ]]; then
  echo "Usage: $0 <stateId> <stateCode>"
  echo "Example: $0 telangana TS"
  exit 1
fi

command -v tippecanoe >/dev/null || { echo "Missing tippecanoe. Run: brew install tippecanoe"; exit 1; }
command -v pmtiles >/dev/null || { echo "Missing pmtiles CLI. Run: npm i -g pmtiles"; exit 1; }

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJ_DIR}"

mkdir -p data_pipeline/out tmp

# We expect these files to exist for the state:
DISTRICTS="data_pipeline/${STATE_ID}_districts_real.geojson"
MANDALS="data_pipeline/${STATE_ID}_mandals.geojson"
VILLAGES="data_pipeline/${STATE_ID}_villages.geojson"

# Outputs
MBTILES="tmp/${STATE_ID}_boundaries.mbtiles"
PMTILES="data_pipeline/out/${STATE_ID}_boundaries.pmtiles"

rm -f "${MBTILES}" "${PMTILES}"

echo "1) Normalizing GeoJSON properties for MapLibre consistency..."
python3 data_pipeline/normalize_properties.py --infile "${DISTRICTS}" --outfile "tmp/norm_${STATE_ID}_districts.geojson" --state "${STATE_CODE}" --level district --name-col district
python3 data_pipeline/normalize_properties.py --infile "${MANDALS}" --outfile "tmp/norm_${STATE_ID}_mandals.geojson" --state "${STATE_CODE}" --level subdistrict --name-col mandal
python3 data_pipeline/normalize_properties.py --infile "${VILLAGES}" --outfile "tmp/norm_${STATE_ID}_villages.geojson" --state "${STATE_CODE}" --level village --name-col village

echo "2) Extracting and optimizing vector topologies with tippecanoe → ${MBTILES}"
# Use explicit zoom levels mapped to MapLibre LOD layers
tippecanoe -o "${MBTILES}" \
  -l districts --minimum-zoom=8  --maximum-zoom=11 "tmp/norm_${STATE_ID}_districts.geojson" \
  -l mandals   --minimum-zoom=11 --maximum-zoom=13 "tmp/norm_${STATE_ID}_mandals.geojson" \
  -l villages  --minimum-zoom=13 --maximum-zoom=16 "tmp/norm_${STATE_ID}_villages.geojson" \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --coalesce-smallest-as-needed \
  --force

echo "3) Converting Vector MBTiles → PMTiles → ${PMTILES}"
pmtiles convert "${MBTILES}" "${PMTILES}"

echo "Done: ${PMTILES}"
