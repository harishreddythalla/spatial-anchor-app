import json
import os

def split_geojson(infile, out_prefix):
    with open(infile, 'r') as f:
        data = json.load(f)
    
    districts = {"type": "FeatureCollection", "features": []}
    mandals = {"type": "FeatureCollection", "features": []}
    villages = {"type": "FeatureCollection", "features": []}
    
    for feature in data['features']:
        props = feature.get('properties', {})
        if props.get('village'):
            villages['features'].append(feature)
        elif props.get('mandal'):
            mandals['features'].append(feature)
        elif props.get('district'):
            districts['features'].append(feature)
            
    with open(f"{out_prefix}_districts_real.geojson", 'w') as f:
        json.dump(districts, f)
    with open(f"{out_prefix}_mandals.geojson", 'w') as f:
        json.dump(mandals, f)
    with open(f"{out_prefix}_villages.geojson", 'w') as f:
        json.dump(villages, f)
    
    print(f"Split {len(data['features'])} features into:")
    print(f"  - Districts: {len(districts['features'])}")
    print(f"  - Mandals: {len(mandals['features'])}")
    print(f"  - Villages: {len(villages['features'])}")

if __name__ == "__main__":
    split_geojson('data_pipeline/in/karnataka.geojson', 'data_pipeline/karnataka')
