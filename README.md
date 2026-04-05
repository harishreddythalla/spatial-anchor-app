# Spatial Anchor Map 🗺️

I have a condition called **Developmental Topographical Disorientation (DTD)**. In plain terms — I get lost. Like, embarrassingly lost. Not "took a wrong turn" lost. More like "I've lived in this city for 3 years and still can't tell you which side of the road my apartment is on" lost.

The frustrating part? Every navigation app out there is built for people who already have a decent mental map. Google Maps will tell you to turn left, but it won't tell you that you're currently in Kondapur mandal, inside Rangareddy district. That context — the administrative container you're physically standing in — is exactly what people like me need to anchor memories to places.

So I built this.

---

## What is this app?

A map app that treats **administrative boundaries as the primary UI element**, not a hidden layer buried 6 taps deep in settings.

Open it and you immediately see:
- Your district outlined in thick indigo
- Your mandal in dashed orange with a colored fill
- Your ward/village in teal
- A banner at the top telling you exactly: `📍 Marathalli → Bangalore Urban → Karnataka`

That banner updates as you walk. The boundary boxes are always visible. You always know which "container" you're in.

For neurotypical people this sounds like clutter. For people with DTD, it's the first time a map app has ever made sense.

---

## The problem with existing apps

Google Maps hides administrative boundaries **on purpose**. Their design philosophy is "reduce visual noise." For 99% of users, that's correct. For the 1% of us who build spatial memory by associating places with named zones — it's a disaster.

I needed something that shows me "you are in Ghatkesar mandal, which is inside Medchal-Malkajgiri district" the moment I open the app. Not after I dig through layers and settings. Just... always there.

---

## Features

### Always-on context banner
Top of the screen, always. Shows your current village → mandal → district hierarchy in real time. Updates as you move. Shows a loading shimmer while GPS is locking. Shows "Outside mapped area" if you're somewhere we don't have data for yet.

### Nested boundary visualization
Three layers, always rendered:
- **Districts** — thick solid indigo border. The big containers.
- **Mandals/Taluks** — dashed orange border with a unique pastel fill per mandal. Each mandal gets its own color so you can visually distinguish neighbors.
- **Villages/Wards** — teal dashed border with light fill. Zoom in past level 13 to see these.

### Route planning with mandal highlighting
Search any two places → get a driving route → every mandal the route crosses gets highlighted in blue. Super useful for understanding "okay this trip goes through Uppal, Ghatkesar, and Bibinagar mandals."

### Breadcrumb trail
Last 30 minutes of your movement drawn as a faint blue polyline. Helps you see exactly which boundaries you've crossed.

### Per-state data download
Don't want all of India on your phone? Pick just the states you need. Telangana is 28MB. Karnataka is 12MB. Download once, works offline.

### Village toggle
Sometimes you're zoomed in and don't need 500 village labels everywhere. One tap hides them all.

---

## How it works under the hood

### Two-layer spatial strategy

**Render layer** — GeoJSON files stored locally (downloaded per-state). The app loads these and draws all the boundary polygons using `flutter_map`'s `PolylineLayer` and `PolygonLayer`. Each mandal gets a unique color from a 12-color pastel palette based on a hash of its name — so the same mandal always gets the same color across sessions.

**Detection layer** — Same GeoJSON files, but used for point-in-polygon detection via a ray-casting algorithm. When your GPS updates, we check which polygon you're inside and update the context banner. This runs synchronously but is fast enough (bounding box pre-filter eliminates 99% of features before ray-casting).

### Data pipeline

All boundary data comes from **OpenStreetMap** via the **Overpass API**. I wrote Python scripts that:
1. Fetch district polygons (admin_level=5), mandal polygons (admin_level=6), and ward polygons (admin_level=9/10) for each state
2. Assemble the disconnected OSM way segments into complete polygon rings
3. Fetch village point nodes (lat/lng only — OSM doesn't have village polygons for most of India)
4. Package everything as per-state GeoJSON files
5. Upload to GitHub Releases for download

The tricky part was **assembling OSM rings**. OSM stores boundaries as a collection of way segments that need to be stitched end-to-end. The assembly algorithm matches segment endpoints within 0.00001 degrees tolerance and handles cases where segments need to be reversed.

### Search

Place search uses a **local-first prefix index** built from the bundled GeoJSON. Type "Ghatke" and it instantly finds "Ghatkesar" from our local data. No network needed, sub-millisecond response. Falls back to Nominatim (OSM's geocoding API) for places we don't have in our dataset.

### Routing

Sends start/end coordinates to the **OSRM** (Open Source Routing Machine) public demo server, gets back a GeoJSON polyline, draws it on the map, then ray-casts every 5th point of the route to build the list of mandals crossed.

---

## Tech stack

| Component | What |
|---|---|
| Framework | Flutter (Dart) |
| Map engine | flutter_map (Leaflet port) |
| Map tiles | CartoDB light_all |
| State management | Riverpod |
| GPS | geolocator |
| Compass | flutter_compass |
| Boundary data | OpenStreetMap / Overpass API |
| Geocoding | Local index + Nominatim |
| Routing | OSRM public demo |
| Storage | GitHub Releases (per-state GeoJSON) |
| Local storage | path_provider + shared_preferences |

**Total infrastructure cost: ₹0/month.**

---

## Data coverage

| State | Districts | Mandals/Taluks | Wards/Villages |
|---|---|---|---|
| Telangana | 33 | 593 | 27,000+ points + GHMC wards |
| Karnataka | 31 | 236 | BBMP wards (548) + village points |

More states coming. The pipeline is already built — just need to run it.

---

## What OSM doesn't have

Rural village boundary polygons don't exist in OpenStreetMap for most of India. What *does* exist:
- Village **points** (lat/lng with a name) — we show these as text labels
- City ward **polygons** for GHMC (Hyderabad) and BBMP (Bangalore) — we show these as proper colored boundaries

This is an OSM data gap, not an app limitation. As OSM contributors map more village boundaries, they'll automatically show up in the next data refresh.

---

## Running it locally

```bash
# Clone the repo
git clone https://github.com/harishreddythalla/spatial_anchor_map
cd spatial_anchor_map

# Install dependencies
flutter pub get

# Run on iOS simulator
open -a Simulator
flutter run

# Build Android APK
flutter build apk --release
```

Requires Flutter 3.41+. iOS 14+ / Android API 21+.

---

## Data pipeline (if you want to refresh or add states)

```bash
cd data_pipeline

# Fetch a state (edit the script for which state)
python3 fetch_all_states.py

# Split into per-state files
python3 split_states.py

# Upload to GitHub Releases
gh release create v1.0 *.geojson manifest.json \
  --repo YOUR_USERNAME/spatial-anchor-data \
  --title "Boundary Data v1.0"
```

---

## Why not Google Maps SDK?

Three reasons:

1. **Cost** — Google Maps charges $7 per 1,000 map loads. At any real scale that adds up fast.
2. **Boundaries are hidden by design** — Google deliberately removes admin boundary lines to reduce visual clutter. You literally cannot show mandal boundaries on Google Maps without an expensive custom tiles setup.
3. **This app is the boundaries** — if you remove the boundaries, there's no app. The entire point is to make administrative zones visible and persistent.

---

## Monetization ideas (thinking out loud)

- Paid app on Play Store / App Store (₹99-199)
- Freemium — base states free, premium states via in-app purchase
- B2B licensing to field survey teams, NGOs, ASHA workers
- Government tender for district administration tools

If you have DTD or know someone who does, and this app helps — that's honestly enough for now.

---

## Contributing

PRs welcome, especially for:
- OSM data quality improvements
- Adding more states to the pipeline
- Performance optimization (the GeoJSON approach gets heavy at scale — PMTiles migration would be great)
- Better DTD-specific UX research

---

*Built because I kept getting lost and none of the existing apps understood why.*