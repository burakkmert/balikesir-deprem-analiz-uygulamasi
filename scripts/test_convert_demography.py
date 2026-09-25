#!/usr/bin/env python3
import unittest
import os
import tempfile
from convert_demography import parse_population_csv, parse_age_dependency_csv, calculate_sha256

class TestDemographyConverter(unittest.TestCase):
    def setUp(self):
        self.raw_dir = os.path.join(os.path.dirname(__file__), "..", "data", "raw")
        self.nufus_csv = os.path.join(self.raw_dir, "nüfus-mahalle.csv")
        self.yas_csv = os.path.join(self.raw_dir, "yaş-mahalle.csv")

    def test_raw_population_reference_values(self):
        result = parse_population_csv(self.nufus_csv)
        self.assertEqual(result["record_count"], 1133)
        self.assertEqual(result["unique_mahalle_codes"], 1133)
        self.assertEqual(result["district_count"], 20)
        self.assertEqual(result["total_population"], 1284514)
        self.assertEqual(len(result["errors"]), 0)

        # Check Altınoluk sample
        altinoluk = next((r for r in result["records"] if "Altınoluk" in r["mahalle_ad"] and r["ilce_ad"] == "Edremit"), None)
        self.assertIsNotNone(altinoluk)
        self.assertEqual(altinoluk["nufus"], 7148)

    def test_raw_age_dependency_reference_values(self):
        result = parse_age_dependency_csv(self.yas_csv)
        self.assertEqual(result["record_count"], 20)
        self.assertEqual(result["unique_ilce_codes"], 20)
        self.assertEqual(len(result["errors"]), 0)

        # Check Susurluk is present
        susurluk = next((r for r in result["records"] if r["ilce_ad"] == "Susurluk"), None)
        self.assertIsNotNone(susurluk)

        # Check Edremit indicators
        edremit = next((r for r in result["records"] if r["ilce_ad"] == "Edremit"), None)
        self.assertIsNotNone(edremit)
        self.assertAlmostEqual(edremit["cocuk_bagimlilik"], 24.44, places=2)
        self.assertAlmostEqual(edremit["toplam_bagimlilik"], 56.59, places=2)
        self.assertAlmostEqual(edremit["yasli_bagimlilik"], 32.16, places=2)

    def test_bom_and_delimiter(self):
        with tempfile.NamedTemporaryFile("w+", encoding="utf-8-sig", delete=False) as f:
            f.write("Header1|||\nHeader2|||\n")
            f.write("2025|Balıkesir(Karesi/Karesi Bel./Test Mah.)-99999|500.0|\n")
            temp_path = f.name

        try:
            res = parse_population_csv(temp_path)
            self.assertEqual(res["record_count"], 1)
            self.assertEqual(res["records"][0]["nufus"], 500)
            self.assertEqual(res["records"][0]["mahalle_ad"], "Test Mah.")
        finally:
            os.remove(temp_path)

    def test_invalid_records_handling(self):
        with tempfile.NamedTemporaryFile("w+", encoding="utf-8-sig", delete=False) as f:
            f.write("2025|Balıkesir(Karesi/Karesi Bel./Test1 Mah.)-111|10.5|\n") # fractional
            f.write("|Balıkesir(Karesi/Karesi Bel./Test2 Mah.)-111|20.0|\n") # duplicate code 111
            f.write("|Balıkesir(Karesi/Karesi Bel./Test3 Mah.)-112|invalid|\n") # invalid number
            temp_path = f.name

        try:
            res = parse_population_csv(temp_path)
            self.assertGreater(len(res["errors"]), 0)
        finally:
            os.remove(temp_path)

if __name__ == "__main__":
    unittest.main()
