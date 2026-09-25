import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from convert_assembly_areas import convert_assembly_areas
from convert_faults import convert_faults

class TestStep5PythonRegressions(unittest.TestCase):

    # --- Assembly Areas Converters Regressions (1 - 5) ---

    def test_assembly_areas_nan_inf_out_of_bounds_fails(self):
        """1. NaN/Inf or out of bounds coordinates cause validation failure and non-zero exit code."""
        bad_kml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <ExtendedData>
        <SchemaData>
          <SimpleData name="id">101</SimpleData>
        </SchemaData>
      </ExtendedData>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              27.8,39.6 27.9,39.6 999.0,39.7 27.8,39.6
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>"""
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'bad.kml')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                f.write(bad_kml)

            with self.assertRaises(SystemExit) as cm:
                convert_assembly_areas(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)
            self.assertFalse(os.path.exists(g_out))

    def test_assembly_areas_open_ring_fails(self):
        """2. Open ring (first != last) causes validation failure and does not auto-close."""
        open_ring_kml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <ExtendedData><SchemaData><SimpleData name="id">102</SimpleData></SchemaData></ExtendedData>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              27.8000,39.6000 27.9000,39.6000 27.9000,39.7000 27.8500,39.6500
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>"""
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'open_ring.kml')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                f.write(open_ring_kml)

            with self.assertRaises(SystemExit) as cm:
                convert_assembly_areas(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)
            self.assertFalse(os.path.exists(g_out))

    def test_assembly_areas_corrupt_point_not_dropped(self):
        """3. Polygon with corrupt point fails validation and does not drop point to form polygon."""
        corrupt_kml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <ExtendedData><SchemaData><SimpleData name="id">103</SimpleData></SchemaData></ExtendedData>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              27.8,39.6 27.9,39.6 INVALID_POINT 27.8,39.7 27.8,39.6
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>"""
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'corrupt.kml')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                f.write(corrupt_kml)

            with self.assertRaises(SystemExit) as cm:
                convert_assembly_areas(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)
            self.assertFalse(os.path.exists(g_out))

    def test_assembly_areas_error_exit_code_and_no_output_on_fail(self):
        """4. Validation failure returns exit code 1, leaves existing output intact, allow_nan=False used."""
        bad_kml = "invalid xml content"
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'invalid.kml')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                f.write(bad_kml)

            with self.assertRaises(SystemExit) as cm:
                convert_assembly_areas(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)
            self.assertFalse(os.path.exists(g_out))

    def test_assembly_areas_multi_placemark_isolation(self):
        """5. Multiple Placemarks preserve their own source Placemark ID reference."""
        multi_kml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <ExtendedData><SchemaData><SimpleData name="id">PM_1</SimpleData></SchemaData></ExtendedData>
      <Polygon>
        <outerBoundaryIs><LinearRing><coordinates>27.8,39.6 27.9,39.6 27.9,39.7 27.8,39.6</coordinates></LinearRing></outerBoundaryIs>
      </Polygon>
    </Placemark>
    <Placemark>
      <ExtendedData><SchemaData><SimpleData name="id">PM_2</SimpleData></SchemaData></ExtendedData>
      <Polygon>
        <outerBoundaryIs><LinearRing><coordinates>27.7,39.5 27.8,39.5 27.8,39.6 27.7,39.5</coordinates></LinearRing></outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>"""
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'multi.kml')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                f.write(multi_kml)

            convert_assembly_areas(input_path, g_out, m_out)
            with open(g_out, 'r', encoding='utf-8') as f:
                geojson = json.load(f)

            self.assertEqual(len(geojson['features']), 2)
            self.assertEqual(geojson['features'][0]['properties']['source_placemark_id'], 'PM_1')
            self.assertEqual(geojson['features'][1]['properties']['source_placemark_id'], 'PM_2')

    # --- Faults Converters Regressions (6 - 8) ---

    def test_faults_validate_all_coordinates_before_clip(self):
        """6. Validate all points in line string even if P1 is inside bounding box."""
        bad_fault_json = {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {"catalog_id": "TEST_001"},
                    "geometry": {
                        "type": "LineString",
                        "coordinates": [
                            [27.8, 39.6],  # Inside box
                            [999.0, 39.6]   # Out of bounds
                        ]
                    }
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'bad_fault.geojson')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                json.dump(bad_fault_json, f)

            with self.assertRaises(SystemExit) as cm:
                convert_faults(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)
            self.assertFalse(os.path.exists(g_out))

    def test_faults_rejects_nan_inf_short_coords(self):
        """7. Rejects NaN, Inf, or short (<2 element) coordinates."""
        short_coord_json = {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {"catalog_id": "TEST_002"},
                    "geometry": {
                        "type": "LineString",
                        "coordinates": [
                            [27.8, 39.6],
                            [27.9]  # Short coordinate
                        ]
                    }
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'short_fault.geojson')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                json.dump(short_coord_json, f)

            with self.assertRaises(SystemExit) as cm:
                convert_faults(input_path, g_out, m_out)
            self.assertEqual(cm.exception.code, 1)

    def test_faults_converter_does_not_require_eur_trcs014(self):
        """8. General converter converts valid small GeoJSON even if EUR_TRCS014 is missing."""
        valid_small_fault = {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {"catalog_id": "CUSTOM_FAULT_01"},
                    "geometry": {
                        "type": "LineString",
                        "coordinates": [
                            [27.8, 39.6],
                            [27.9, 39.7]
                        ]
                    }
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, 'custom_fault.geojson')
            g_out = os.path.join(tmpdir, 'out.geojson')
            m_out = os.path.join(tmpdir, 'out.json')
            with open(input_path, 'w', encoding='utf-8') as f:
                json.dump(valid_small_fault, f)

            convert_faults(input_path, g_out, m_out)
            self.assertTrue(os.path.exists(g_out))
            with open(g_out, 'r', encoding='utf-8') as f:
                data = json.load(f)
            self.assertEqual(len(data['features']), 1)
            self.assertEqual(data['features'][0]['properties']['catalog_id'], 'CUSTOM_FAULT_01')

if __name__ == '__main__':
    unittest.main()
