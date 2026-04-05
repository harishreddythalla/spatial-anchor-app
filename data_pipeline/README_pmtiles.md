## Build boundary overlay PMTiles (Raster)

These `.pmtiles` files are **raster overlays** (fast to render) used by the app to draw boundaries smoothly on Android.

### Prereqs

- **GDAL** (ogr2ogr, gdal_rasterize, gdal_translate, gdaladdo)
- **pmtiles** CLI (`pmtiles convert`)

macOS:

```bash
brew install gdal
npm i -g pmtiles
```

### Build

From `spatial_anchor_map/`:

```bash
chmod +x data_pipeline/build_boundary_pmtiles.sh
./data_pipeline/build_boundary_pmtiles.sh telangana /path/to/telangana.geojson
./data_pipeline/build_boundary_pmtiles.sh karnataka /path/to/karnataka.geojson
```

Outputs:

```text
data_pipeline/out/telangana_boundaries.pmtiles
data_pipeline/out/karnataka_boundaries.pmtiles
```

### Where to upload (important)

Upload these two files to your GitHub release that matches:

`spatial_anchor_map/lib/services/state_download_service.dart` → `_baseUrl`

Currently `_baseUrl` points at:

`https://github.com/harishreddythalla/spatial-anchor-data/releases/download/v2.0`

So you should upload the PMTiles as **release assets** to:

- Release tag **`v2.0`** in repo **`harishreddythalla/spatial-anchor-data`**

With exact filenames:

- `telangana_boundaries.pmtiles`
- `karnataka_boundaries.pmtiles`

Once uploaded, the app will auto-download them (per manifest) and switch to raster overlays for ultra-smooth performance.

