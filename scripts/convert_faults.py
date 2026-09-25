#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import os
import sys

MIN_LON, MIN_LAT = 26.3, 39.1
MAX_LON, MAX_LAT = 28.9, 40.7

def point_in_box(lon, lat):
    return MIN_LON <= lon <= MAX_LON and MIN_LAT <= lat <= MAX_LAT

def validate_coordinate(pt, feat_idx, point_idx):
    if not isinstance(pt, (list, tuple)) or len(pt) < 2:
        return f"Feature #{feat_idx} point #{point_idx}: Coordinate has fewer than 2 elements: {pt}"
    try:
        lon = float(pt[0])
        lat = float(pt[1])
    except (ValueError, TypeError):
        return f"Feature #{feat_idx} point #{point_idx}: Invalid float coordinate: {pt}"

    if math.isnan(lon) or math.isinf(lon) or math.isnan(lat) or math.isinf(lat):
        return f"Feature #{feat_idx} point #{point_idx}: Non-finite coordinate (NaN/Inf): {pt}"

    if not (-180.0 <= lon <= 180.0 and -90.0 <= lat <= 90.0):
        return f"Feature #{feat_idx} point #{point_idx}: Coordinate out of bounds [-180..180, -90..90]: [{lon}, {lat}]"

    return None

def validate_feature_geometry(feat, feat_idx):
    geom = feat.get('geometry')
    if not geom or not isinstance(geom, dict):
        return [f"Feature #{feat_idx}: Missing or invalid geometry object"]

    g_type = geom.get('type')
    coords = geom.get('coordinates')

    if g_type not in ('LineString', 'MultiLineString'):
        return [f"Feature #{feat_idx}: Unsupported geometry type '{g_type}' (expected LineString or MultiLineString)"]

    if not coords or not isinstance(coords, list):
        return [f"Feature #{feat_idx}: Empty or invalid coordinates array"]

    errors = []
    if g_type == 'LineString':
        if len(coords) < 2:
            errors.append(f"Feature #{feat_idx}: LineString has fewer than 2 points")
        for p_idx, pt in enumerate(coords, start=1):
            err = validate_coordinate(pt, feat_idx, p_idx)
            if err:
                errors.append(err)
    elif g_type == 'MultiLineString':
        for line_idx, line in enumerate(coords, start=1):
            if not isinstance(line, list) or len(line) < 2:
                errors.append(f"Feature #{feat_idx} MultiLineString line #{line_idx}: Line has fewer than 2 points")
                continue
            for p_idx, pt in enumerate(line, start=1):
                err = validate_coordinate(pt, feat_idx, f"{line_idx}.{p_idx}")
                if err:
                    errors.append(err)
    return errors

def segment_intersects_box(p1, p2):
    x1, y1 = float(p1[0]), float(p1[1])
    x2, y2 = float(p2[0]), float(p2[1])

    if point_in_box(x1, y1) or point_in_box(x2, y2):
        return True

    def get_code(x, y):
        code = 0
        if x < MIN_LON: code |= 1
        elif x > MAX_LON: code |= 2
        if y < MIN_LAT: code |= 4
        elif y > MAX_LAT: code |= 8
        return code

    c1 = get_code(x1, y1)
    c2 = get_code(x2, y2)

    while True:
        if not (c1 | c2):
            return True
        if c1 & c2:
            return False

        code_out = c1 if c1 else c2
        if code_out & 8: # top
            if y2 == y1: return False
            x = x1 + (x2 - x1) * (MAX_LAT - y1) / (y2 - y1)
            y = MAX_LAT
        elif code_out & 4: # bottom
            if y2 == y1: return False
            x = x1 + (x2 - x1) * (MIN_LAT - y1) / (y2 - y1)
            y = MIN_LAT
        elif code_out & 2: # right
            if x2 == x1: return False
            y = y1 + (y2 - y1) * (MAX_LON - x1) / (x2 - x1)
            x = MAX_LON
        elif code_out & 1: # left
            if x2 == x1: return False
            y = y1 + (y2 - y1) * (MIN_LON - x1) / (x2 - x1)
            x = MIN_LON

        if code_out == c1:
            x1, y1 = x, y
            c1 = get_code(x1, y1)
        else:
            x2, y2 = x, y
            c2 = get_code(x2, y2)

def feature_intersects_box(feat):
    geom = feat.get('geometry', {})
    g_type = geom.get('type')
    coords = geom.get('coordinates', [])

    if g_type == 'LineString':
        for i in range(len(coords) - 1):
            if segment_intersects_box(coords[i], coords[i+1]):
                return True
    elif g_type == 'MultiLineString':
        for line in coords:
            for i in range(len(line) - 1):
                if segment_intersects_box(line[i], line[i+1]):
                    return True
    return False

def convert_faults(input_path, output_geojson_path, output_meta_path):
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Source GeoJSON not found: {input_path}")

    with open(input_path, 'rb') as f:
        raw_bytes = f.read()

    sha256_hash = hashlib.sha256(raw_bytes).hexdigest()
    try:
        global_data = json.loads(raw_bytes.decode('utf-8'))
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON decode error in file '{input_path}': {e}", file=sys.stderr)
        sys.exit(1)

    global_features = global_data.get('features', [])
    validation_errors = []

    # First pass: Validate ALL features and ALL coordinates BEFORE clipping/filtering
    for idx, feat in enumerate(global_features, start=1):
        errs = validate_feature_geometry(feat, idx)
        if errs:
            validation_errors.extend(errs)

    if validation_errors:
        print(f"[ERROR] Validation failed for Faults GeoJSON '{input_path}' with {len(validation_errors)} error(s):", file=sys.stderr)
        for err in validation_errors[:20]:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    selected_features = []
    for idx, feat in enumerate(global_features, start=1):
        if feature_intersects_box(feat):
            props = dict(feat.get('properties', {}))
            props['tech_id'] = f"fault_geom_{len(selected_features)+1:04d}"
            
            selected_features.append({
                'type': 'Feature',
                'properties': props,
                'geometry': feat.get('geometry')
            })

    eur_trcs014_present = any(
        'EUR_TRCS014' in str(f['properties'].get('catalog_id')) or
        'EUR_TRCS014' in str(f['properties'].get('catalog_name')) or
        'EUR_TRCS014' in str(f['properties'])
        for f in selected_features
    )

    output_geojson = {
        'type': 'FeatureCollection',
        'features': selected_features
    }

    metadata = {
        'schema_version': 1,
        'source_filename': os.path.basename(input_path),
        'source_sha256': sha256_hash,
        'global_feature_count': len(global_features),
        'selected_feature_count': len(selected_features),
        'bounding_box': {
            'min_lon': MIN_LON,
            'min_lat': MIN_LAT,
            'max_lon': MAX_LON,
            'max_lat': MAX_LAT
        },
        'filtering_method': 'Segment-box intersection (Cohen-Sutherland)',
        'source_repository': 'https://github.com/GEMScienceTools/gem-global-active-faults',
        'license': 'CC BY-SA 4.0',
        'eur_trcs014_verified': eur_trcs014_present,
        'scope_note': "Seçim kutusu Balıkesir bölgesel odağını kapsar; Balıkesir'in resmî idari sınırı değildir ve eksiksiz tüm fay hatlarını temsil ettiği iddia edilmez."
    }

    os.makedirs(os.path.dirname(output_geojson_path), exist_ok=True)
    os.makedirs(os.path.dirname(output_meta_path), exist_ok=True)

    with open(output_geojson_path, 'w', encoding='utf-8') as f:
        json.dump(output_geojson, f, ensure_ascii=False, indent=2, allow_nan=False)

    with open(output_meta_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2, allow_nan=False)

    print(f"Successfully converted Faults GeoJSON & Metadata:")
    print(f"  GeoJSON: {output_geojson_path} ({len(selected_features)} features selected out of {len(global_features)})")
    print(f"  Metadata: {output_meta_path} (EUR_TRCS014 verified: {eur_trcs014_present})")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Convert GEM active faults GeoJSON to Balıkesir regional GeoJSON & Metadata")
    parser.add_argument('--input', default='data/raw/gem_active_faults.geojson', help='Input global GeoJSON path')
    parser.add_argument('--output-geojson', default='assets/data/balikesir_fay_hatlari.geojson', help='Output GeoJSON path')
    parser.add_argument('--output-meta', default='assets/data/balikesir_fay_metadata.json', help='Output Metadata JSON path')
    args = parser.parse_args()

    convert_faults(args.input, args.output_geojson, args.output_meta)
