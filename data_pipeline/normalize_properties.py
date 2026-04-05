import json
import argparse
import sys
import os

def normalize_geojson(infile, outfile, state_code, admin_level, name_col):
    with open(infile, 'r') as f:
        data = json.load(f)
    
    for feature in data.get('features', []):
        props = feature.get('properties', {})
        # Safety fallback if exact col name doesn't exist
        name_val = props.get(name_col)
        
        # Sometimes keys are lowercase, uppercase, etc.
        if name_val is None:
            # Let's try matching case-insensitively
            for k, v in props.items():
                if k.lower() == name_col.lower():
                    name_val = v
                    break
                    
        if name_val is None:
            name_val = 'Unknown'

        # Standardize keys MapLibre styles and Map matching will depend on
        new_props = {
            'state_code': state_code,
            'admin_level': admin_level,
            'name': name_val,
        }
        
        # Update the properties object
        props.update(new_props)
        feature['properties'] = props
        
    with open(outfile, 'w') as f:
        json.dump(data, f)
        
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Normalize GeoJSON properties for MapLibre Vector Tiles")
    parser.add_argument('--infile', required=True, help="Input GeoJSON file")
    parser.add_argument('--outfile', required=True, help="Output normalized GeoJSON file")
    parser.add_argument('--state', required=True, help="State code (e.g. TS, KA)")
    parser.add_argument('--level', required=True, help="Administrative level (e.g. district, mandal, village)")
    parser.add_argument('--name-col', required=True, help="Property key containing the name feature")
    
    args = parser.parse_args()
    
    # Ensure out directory exists
    os.makedirs(os.path.dirname(os.path.abspath(args.outfile)), exist_ok=True)
    
    normalize_geojson(args.infile, args.outfile, args.state, args.level, args.name_col)
    print(f"Normalized {args.infile} -> {args.outfile} (Level: {args.level}, State: {args.state})")
