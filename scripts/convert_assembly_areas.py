#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import os
import sys
import xml.etree.ElementTree as ET

def parse_oznitelik_list(oznitelik_str):
    if not oznitelik_str:
        return {}
    
    result = {}
    items = oznitelik_str.split(',')
    for item in items:
        if '-' in item:
            parts = item.split('-', 1)
            key = parts[0].strip()
            val = parts[1].strip()
            result[key] = val
    return result

def parse_boolean_attribute(val_str):
    if not val_str:
        return None
    val_clean = val_str.strip().upper()
    if val_clean in ('VAR', '1', 'TRUE', 'EVET'):
        return True
    if val_clean in ('YOK', '0', 'FALSE', 'HAYIR'):
        return False
    return None

def parse_kml_coordinates(coords_text):
    ring = []
    errors = []
    tokens = coords_text.strip().split()
    if not tokens:
        return [], ["Empty coordinate string"]

    for token_idx, token in enumerate(tokens, start=1):
        parts = token.split(',')
        if len(parts) < 2:
            errors.append(f"Token #{token_idx} '{token}' has fewer than 2 coordinate components")
            continue
        try:
            lng = float(parts[0])
            lat = float(parts[1])
        except ValueError:
            errors.append(f"Token #{token_idx} '{token}' contains invalid float values")
            continue

        if math.isnan(lng) or math.isinf(lng) or math.isnan(lat) or math.isinf(lat):
            errors.append(f"Token #{token_idx} '{token}' contains non-finite coordinate (NaN/Inf)")
            continue

        if not (-180.0 <= lng <= 180.0 and -90.0 <= lat <= 90.0):
            errors.append(f"Token #{token_idx} '{token}' out of bounds [-180..180, -90..90]: [{lng}, {lat}]")
            continue

        ring.append([lng, lat])

    if len(ring) < 4:
        errors.append(f"LinearRing has fewer than 4 valid points ({len(ring)})")
    elif ring[0] != ring[-1]:
        # Strict policy: DO NOT automatically close ring; report explicit validation error
        errors.append("LinearRing is not closed (first point != last point)")

    return ring, errors

def convert_assembly_areas(input_path, output_geojson_path, output_meta_path):
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Source KML file not found: {input_path}")
    
    with open(input_path, 'rb') as f:
        raw_bytes = f.read()
    
    sha256_hash = hashlib.sha256(raw_bytes).hexdigest()
    
    try:
        root = ET.fromstring(raw_bytes)
    except ET.ParseError as e:
        print(f"[ERROR] XML Parse Error in KML file '{input_path}': {e}", file=sys.stderr)
        sys.exit(1)

    ns = {'kml': 'http://www.opengis.net/kml/2.2'}
    
    placemarks = root.findall('.//kml:Placemark', ns)
    all_polygons = root.findall('.//kml:Polygon', ns)
    
    placemark_count = len(placemarks)
    polygon_count = len(all_polygons)
    validation_errors = []

    # Map polygons to their parent Placemark ID
    # In valid KML, Polygon elements reside inside Placemark elements.
    features = []
    inner_boundary_total = 0
    feature_counter = 0

    if placemarks:
        for pm_idx, pm in enumerate(placemarks, start=1):
            ed = pm.find('kml:ExtendedData', ns)
            ext_dict = {}
            if ed is not None:
                for schema_data in ed:
                    for simple_data in schema_data:
                        name = simple_data.attrib.get('name')
                        val = simple_data.text
                        if name:
                            ext_dict[name] = val
            
            pm_id = ext_dict.get('id')
            oznitelik_map = parse_oznitelik_list(ext_dict.get('oznitelikList', ''))
            
            alan_m2_raw = oznitelik_map.get('Otomatik Hesaplanan Alan (M2)')
            if alan_m2_raw:
                try:
                    alan_m2 = float(alan_m2_raw)
                    if math.isnan(alan_m2) or math.isinf(alan_m2) or alan_m2 < 0:
                        validation_errors.append(f"Placemark #{pm_idx} (id={pm_id}): Invalid alan_m2 value '{alan_m2_raw}'")
                except ValueError:
                    validation_errors.append(f"Placemark #{pm_idx} (id={pm_id}): Invalid float format for alan_m2 '{alan_m2_raw}'")

            # Find polygons inside THIS placemark
            pm_polygons = pm.findall('.//kml:Polygon', ns)
            for poly_idx, poly in enumerate(pm_polygons, start=1):
                feature_counter += 1
                feature_id = f"assembly_geom_{feature_counter:04d}"

                outer_elem = poly.find('kml:outerBoundaryIs/kml:LinearRing/kml:coordinates', ns)
                if outer_elem is None or not outer_elem.text:
                    validation_errors.append(f"Placemark #{pm_idx} Polygon #{poly_idx}: Missing outer boundary coordinates")
                    continue

                outer_ring, errs = parse_kml_coordinates(outer_elem.text)
                if errs:
                    for e in errs:
                        validation_errors.append(f"Placemark #{pm_idx} Polygon #{poly_idx} outer boundary: {e}")

                rings = [outer_ring] if outer_ring else []

                inner_elems = poly.findall('kml:innerBoundaryIs/kml:LinearRing/kml:coordinates', ns)
                for inner_idx, inner_elem in enumerate(inner_elems, start=1):
                    if inner_elem.text:
                        inner_ring, i_errs = parse_kml_coordinates(inner_elem.text)
                        if i_errs:
                            for e in i_errs:
                                validation_errors.append(f"Placemark #{pm_idx} Polygon #{poly_idx} inner boundary #{inner_idx}: {e}")
                        if inner_ring:
                            rings.append(inner_ring)
                            inner_boundary_total += 1

                if outer_ring and not errs:
                    feature = {
                        'type': 'Feature',
                        'properties': {
                            'id': feature_id,
                            'source_placemark_id': pm_id,
                            'is_per_area_attribute_matched': False,
                            'note': 'Bu geometri parçası için alan bazlı resmî öznitelik eşleşmesi doğrulanmamıştır.'
                        },
                        'geometry': {
                            'type': 'Polygon',
                            'coordinates': rings
                        }
                    }
                    features.append(feature)
    else:
        # No Placemark container: check unlinked polygons
        for poly_idx, poly in enumerate(all_polygons, start=1):
            validation_errors.append(f"Unlinked Polygon #{poly_idx}: Polygon has no parent Placemark reference")

    # If there are any validation errors, do NOT write output files and exit with code 1
    if validation_errors:
        print(f"[ERROR] Validation failed for KML '{input_path}' with {len(validation_errors)} error(s):", file=sys.stderr)
        for err in validation_errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    single_record = {}
    if placemark_count == 1 and placemarks:
        pm = placemarks[0]
        ed = pm.find('kml:ExtendedData', ns)
        ext_dict = {}
        if ed is not None:
            for schema_data in ed:
                for simple_data in schema_data:
                    name = simple_data.attrib.get('name')
                    val = simple_data.text
                    if name:
                        ext_dict[name] = val
        oznitelik_map = parse_oznitelik_list(ext_dict.get('oznitelikList', ''))
        
        alan_m2_val = None
        if oznitelik_map.get('Otomatik Hesaplanan Alan (M2)'):
            try:
                alan_m2_val = float(oznitelik_map.get('Otomatik Hesaplanan Alan (M2)'))
            except ValueError:
                pass

        single_record = {
            'id': ext_dict.get('id'),
            'ad': ext_dict.get('ad', ''),
            'il': ext_dict.get('il', ''),
            'ilce': ext_dict.get('ilce', ''),
            'mahalle': ext_dict.get('mahalle', ''),
            'alan_m2': alan_m2_val,
            'su': parse_boolean_attribute(oznitelik_map.get('Su')),
            'elektrik': parse_boolean_attribute(oznitelik_map.get('Elektrik')),
            'wc': parse_boolean_attribute(oznitelik_map.get('WC/Kanalizasyon')),
            'tabela_kod': oznitelik_map.get('Tabela Kod'),
            'yol_durumu': parse_boolean_attribute(oznitelik_map.get('Yol Durumu')),
            'veri_uretim': oznitelik_map.get('Veri Üretim'),
            'raw_oznitelik': ext_dict.get('oznitelikList', '')
        }

    geojson_data = {
        'type': 'FeatureCollection',
        'features': features
    }
    
    metadata_data = {
        'schema_version': 1,
        'source_filename': os.path.basename(input_path),
        'source_sha256': sha256_hash,
        'dataset_url': 'https://acikveri.balikesir.bel.tr/dataset/acil-toplanma-alanlari',
        'placemark_count': placemark_count,
        'polygon_count': len(features),
        'inner_boundary_count': inner_boundary_total,
        'official_distinct_areas_count': None,
        'is_per_area_attribute_matched': False,
        'single_source_record': single_record,
        'validation_error_count': 0
    }
    
    os.makedirs(os.path.dirname(output_geojson_path), exist_ok=True)
    os.makedirs(os.path.dirname(output_meta_path), exist_ok=True)
    
    with open(output_geojson_path, 'w', encoding='utf-8') as f:
        json.dump(geojson_data, f, ensure_ascii=False, indent=2, allow_nan=False)
    
    with open(output_meta_path, 'w', encoding='utf-8') as f:
        json.dump(metadata_data, f, ensure_ascii=False, indent=2, allow_nan=False)
    
    print(f"Successfully converted KML to GeoJSON and Metadata:")
    print(f"  GeoJSON: {output_geojson_path} ({len(features)} features)")
    print(f"  Metadata: {output_meta_path} (Placemarks: {placemark_count}, Inner boundaries: {inner_boundary_total})")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Convert assembly areas KML to GeoJSON & Metadata")
    parser.add_argument('--input', default='data/raw/toplanma-alanlari-.kml', help='Input KML file path')
    parser.add_argument('--output-geojson', default='assets/data/balikesir_toplanma_geometrileri.geojson', help='Output GeoJSON file path')
    parser.add_argument('--output-meta', default='assets/data/balikesir_toplanma_metadata.json', help='Output Metadata JSON file path')
    args = parser.parse_args()
    
    convert_assembly_areas(args.input, args.output_geojson, args.output_meta)
