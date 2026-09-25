import os
import hashlib
import xml.etree.ElementTree as ET

def inspect_kml(kml_path):
    with open(kml_path, 'rb') as f:
        content = f.read()

    sha256 = hashlib.sha256(content).hexdigest()
    size_bytes = len(content)

    print(f'File Size: {size_bytes} bytes')
    print(f'SHA-256: {sha256}')

    root = ET.fromstring(content)
    ns = {'kml': 'http://www.opengis.net/kml/2.2'}

    placemarks = root.findall('.//kml:Placemark', ns)
    extended_data = root.findall('.//kml:ExtendedData', ns)
    polygons = root.findall('.//kml:Polygon', ns)
    outer_boundaries = root.findall('.//kml:outerBoundaryIs', ns)
    inner_boundaries = root.findall('.//kml:innerBoundaryIs', ns)
    coordinates = root.findall('.//kml:coordinates', ns)

    print(f'Placemarks: {len(placemarks)}')
    print(f'ExtendedData: {len(extended_data)}')
    print(f'Polygons: {len(polygons)}')
    print(f'outerBoundaryIs: {len(outer_boundaries)}')
    print(f'innerBoundaryIs: {len(inner_boundaries)}')
    print(f'coordinates elements: {len(coordinates)}')

    for p in placemarks:
        print('--- Placemark Details ---')
        for child in p:
            tag = child.tag.split('}')[-1]
            if tag not in ['MultiGeometry', 'Polygon', 'Style', 'styleUrl']:
                print(f'  {tag}: {child.text or "[complex]"}')

    for ed in extended_data:
        print('--- ExtendedData Details ---')
        for schema_data in ed:
            for simple_data in schema_data:
                print(f'  {simple_data.attrib.get("name")}: {simple_data.text}')

if __name__ == '__main__':
    inspect_kml('data/raw/toplanma-alanlari-.kml')
