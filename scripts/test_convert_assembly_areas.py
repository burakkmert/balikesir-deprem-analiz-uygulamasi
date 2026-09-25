import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from convert_assembly_areas import convert_assembly_areas, parse_boolean_attribute, parse_oznitelik_list

class TestConvertAssemblyAreas(unittest.TestCase):
    def setUp(self):
        self.kml_path = 'data/raw/toplanma-alanlari-.kml'

    def test_parse_boolean_attribute(self):
        self.assertTrue(parse_boolean_attribute("Var"))
        self.assertTrue(parse_boolean_attribute("var"))
        self.assertFalse(parse_boolean_attribute("Yok"))
        self.assertFalse(parse_boolean_attribute("yok"))
        self.assertIsNone(parse_boolean_attribute(""))
        self.assertIsNone(parse_boolean_attribute(None))

    def test_parse_oznitelik_list(self):
        raw = "Açık Adres - Balıkesir ,Kepsut,Otomatik Hesaplanan Alan (M2) - 545.78,Su - Var,WC/Kanalizasyon - Yok"
        res = parse_oznitelik_list(raw)
        self.assertEqual(res.get("Otomatik Hesaplanan Alan (M2)"), "545.78")
        self.assertEqual(res.get("Su"), "Var")
        self.assertEqual(res.get("WC/Kanalizasyon"), "Yok")

    def test_conversion_counts_and_attributes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            geojson_path = os.path.join(tmpdir, 'geometriler.geojson')
            meta_path = os.path.join(tmpdir, 'metadata.json')

            convert_assembly_areas(self.kml_path, geojson_path, meta_path)

            self.assertTrue(os.path.exists(geojson_path))
            self.assertTrue(os.path.exists(meta_path))

            with open(geojson_path, 'r', encoding='utf-8') as f:
                geojson = json.load(f)

            with open(meta_path, 'r', encoding='utf-8') as f:
                meta = json.load(f)

            # 1. Feature counts
            self.assertEqual(geojson['type'], 'FeatureCollection')
            self.assertEqual(len(geojson['features']), 1682)

            # 2. Metadata counts
            self.assertEqual(meta['placemark_count'], 1)
            self.assertEqual(meta['polygon_count'], 1682)
            self.assertEqual(meta['inner_boundary_count'], 2)
            self.assertIsNone(meta['official_distinct_areas_count'])
            self.assertFalse(meta['is_per_area_attribute_matched'])

            # 3. Inner boundaries check in GeoJSON features
            inner_boundary_found = 0
            for feat in geojson['features']:
                coords = feat['geometry']['coordinates']
                if len(coords) > 1:
                    inner_boundary_found += len(coords) - 1
                
                # Check Kepsut properties NOT copied to feature level
                props = feat['properties']
                self.assertNotIn('ad', props)
                self.assertNotIn('ilce', props)
                self.assertNotIn('su', props)
                self.assertFalse(props['is_per_area_attribute_matched'])

            self.assertEqual(inner_boundary_found, 2)

            # 4. Single source record check
            single = meta['single_source_record']
            self.assertEqual(single['id'], '59183426')
            self.assertEqual(single['ad'], 'KEPSUT_62_NOLU_TOPLANMA_ALANI')
            self.assertEqual(single['ilce'], 'KEPSUT')
            self.assertEqual(single['mahalle'], 'YEŞİLDAĞ')
            self.assertAlmostEqual(single['alan_m2'], 545.781273959205, places=4)
            self.assertTrue(single['su'])
            self.assertTrue(single['elektrik'])
            self.assertTrue(single['wc'])

    def test_deterministic_reproduction(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            g1 = os.path.join(tmpdir, 'g1.geojson')
            m1 = os.path.join(tmpdir, 'm1.json')
            g2 = os.path.join(tmpdir, 'g2.geojson')
            m2 = os.path.join(tmpdir, 'm2.json')

            convert_assembly_areas(self.kml_path, g1, m1)
            convert_assembly_areas(self.kml_path, g2, m2)

            with open(g1, 'r', encoding='utf-8') as f:
                content_g1 = f.read()
            with open(g2, 'r', encoding='utf-8') as f:
                content_g2 = f.read()

            with open(m1, 'r', encoding='utf-8') as f:
                content_m1 = f.read()
            with open(m2, 'r', encoding='utf-8') as f:
                content_m2 = f.read()

            self.assertEqual(content_g1, content_g2)
            self.assertEqual(content_m1, content_m2)

if __name__ == '__main__':
    unittest.main()
