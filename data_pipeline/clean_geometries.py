import json
from shapely.geometry import shape, mapping
from shapely.validation import make_valid

def clean_file(filepath):
    print(f"Cleaning {filepath}...")
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    cleaned_features = []
    for f in data.get('features', []):
        geom_dict = f.get('geometry')
        if not geom_dict:
            cleaned_features.append(f)
            continue
            
        try:
            geom = shape(geom_dict)
            if not geom.is_valid:
                valid_geom = make_valid(geom)
                # make_valid can return GeometryCollection of Polygons, Lines, Points
                # We only want Polygons and MultiPolygons
                if valid_geom.geom_type in ('Polygon', 'MultiPolygon'):
                    f['geometry'] = mapping(valid_geom)
                elif valid_geom.geom_type == 'GeometryCollection':
                    polys = [g for g in valid_geom.geoms if g.geom_type in ('Polygon', 'MultiPolygon')]
                    if polys:
                        from shapely.ops import unary_union
                        f['geometry'] = mapping(unary_union(polys))
                    else:
                        continue # drop unrecoverable geometry
                else:
                    continue # drop lines/points that can't form polygons
            cleaned_features.append(f)
        except Exception as e:
            # If shape conversion fails, keep as is
            cleaned_features.append(f)
            
    data['features'] = cleaned_features
    with open(filepath, 'w') as f:
        json.dump(data, f)
    print(f"Done cleaning {filepath}")

clean_file("data_pipeline/state_files/karnataka.geojson")
clean_file("data_pipeline/state_files/telangana.geojson")
