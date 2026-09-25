import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from convert_faults import convert_faults, segment_intersects_box, feature_intersects_box

class TestConvertFaults(unittest.TestCase):
    def setUp(self):
        self.fault_path = 'data/raw/gem_active_faults.geojson'

    def test_segment_intersects_box(self):
        # 1. Line endpoints outside box crossing through box
        p1 = [25.0, 40.0]
        p2 = [30.0, 40.0]
        self.assertTrue(segment_intersects_box(p1, p2))

        # 2. Line touching box boundary at minLon = 26.3
        p3 = [26.3, 39.5]
        p4 = [26.3, 40.5]
        self.assertTrue(segment_intersects_box(p3, p4))

        # 3. Line completely outside
        p5 = [20.0, 30.0]
        p6 = [21.0, 31.0]
        self.assertFalse(segment_intersects_box(p5, p6))

    def test_multilinestring_handling(self):
        feat = {
            'type': 'Feature',
            'geometry': {
                'type': 'MultiLineString',
                'coordinates': [
                    [[20.0, 30.0], [21.0, 31.0]], # Outside
                    [[27.0, 39.5], [28.0, 40.0]]  # Inside
                ]
            },
            'properties': {'catalog_id': 'TEST_MLS'}
        }
        self.assertTrue(feature_intersects_box(feat))

    def test_real_conversion_and_reference_values(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            g_path = os.path.join(tmpdir, 'faylar.geojson')
            m_path = os.path.join(tmpdir, 'metadata.json')

            convert_faults(self.fault_path, g_path, m_path)

            with open(g_path, 'r', encoding='utf-8') as f:
                geo = json.load(f)
            with open(m_path, 'r', encoding='utf-8') as f:
                meta = json.load(f)

            self.assertEqual(len(geo['features']), 60)
            self.assertEqual(meta['global_feature_count'], 16195)
            self.assertEqual(meta['selected_feature_count'], 60)

            eur_found = any('EUR_TRCS014' in str(f['properties']) for f in geo['features'])
            self.assertTrue(eur_found)

    def test_deterministic_reproduction(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            g1 = os.path.join(tmpdir, 'g1.geojson')
            m1 = os.path.join(tmpdir, 'm1.json')
            g2 = os.path.join(tmpdir, 'g2.geojson')
            m2 = os.path.join(tmpdir, 'm2.json')

            convert_faults(self.fault_path, g1, m1)
            convert_faults(self.fault_path, g2, m2)

            with open(g1, 'r', encoding='utf-8') as f:
                c_g1 = f.read()
            with open(g2, 'r', encoding='utf-8') as f:
                c_g2 = f.read()

            self.assertEqual(c_g1, c_g2)

if __name__ == '__main__':
    unittest.main()
