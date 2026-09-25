#!/usr/bin/env python3
import argparse
import csv
import hashlib
import json
import os
import math
import re
import sys

def calculate_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def parse_population_csv(csv_path):
    sha256 = calculate_sha256(csv_path)
    records = []
    unique_codes = set()
    district_names = set()
    total_population = 0
    current_year = None
    errors = []

    # Regex for: Balıkesir(Altıeylül/Altıeylül Bel./1.Gündoğan Mah.)-10319
    pattern = re.compile(r"^Balıkesir\(([^/]+)/.+?/([^\)]+)\)-(\d+)$")

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f, delimiter="|")
        line_num = 0
        for row in reader:
            line_num += 1
            if not row or len(row) < 3:
                continue

            year_cell = row[0].strip()
            text_cell = row[1].strip()
            val_cell = row[2].strip()

            if year_cell and year_cell.isdigit():
                current_year = int(year_cell)

            if not text_cell or not text_cell.startswith("Balıkesir"):
                continue

            match = pattern.match(text_cell)
            if not match:
                errors.append(f"Line {line_num}: Pattern match failed for '{text_cell}'")
                continue

            ilce_ad = match.group(1).strip()
            mahalle_ad = match.group(2).strip()
            mahalle_kodu = match.group(3).strip()

            if not val_cell:
                errors.append(f"Line {line_num}: Empty population value")
                continue

            try:
                pop_float = float(val_cell)
                if math.isnan(pop_float) or math.isinf(pop_float) or pop_float < 0:
                    errors.append(f"Line {line_num}: Invalid non-finite or negative population '{val_cell}'")
                    continue
                
                pop_int = int(pop_float)
                if pop_float != pop_int:
                    errors.append(f"Line {line_num}: Fractional population {pop_float}")
                    continue
            except ValueError:
                errors.append(f"Line {line_num}: Invalid number format '{val_cell}'")
                continue

            if mahalle_kodu in unique_codes:
                errors.append(f"Line {line_num}: Duplicate mahalle_kodu '{mahalle_kodu}'")
                continue

            if current_year is None:
                errors.append(f"Line {line_num}: Missing data year")
                continue

            unique_codes.add(mahalle_kodu)
            district_names.add(ilce_ad)
            total_population += pop_int

            records.append({
                "mahalle_kodu": mahalle_kodu,
                "mahalle_ad": mahalle_ad,
                "ilce_ad": ilce_ad,
                "nufus": pop_int,
                "yil": current_year
            })

    if current_year is None:
        errors.append("CSV file contained no valid year declaration")

    return {
        "schema_version": "1.0.0",
        "data_year": current_year,
        "geographic_level": "mahalle",
        "source_filename": os.path.basename(csv_path),
        "source_sha256": sha256,
        "record_count": len(records),
        "unique_mahalle_codes": len(unique_codes),
        "district_count": len(district_names),
        "total_population": total_population,
        "errors": errors,
        "records": records
    }

def parse_age_dependency_csv(csv_path):
    sha256 = calculate_sha256(csv_path)
    records = []
    unique_codes = set()
    current_year = None
    errors = []

    # Regex for: Balıkesir(Altıeylül)-2077
    pattern = re.compile(r"^Balıkesir\(([^\)]+)\)-(\d+)$")

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f, delimiter="|")
        line_num = 0
        for row in reader:
            line_num += 1
            if not row or len(row) < 5:
                continue

            year_cell = row[0].strip()
            text_cell = row[1].strip()
            cocuk_cell = row[2].strip()
            toplam_cell = row[3].strip()
            yasli_cell = row[4].strip()

            if year_cell and year_cell.isdigit():
                current_year = int(year_cell)

            if not text_cell or not text_cell.startswith("Balıkesir"):
                continue

            match = pattern.match(text_cell)
            if not match:
                errors.append(f"Line {line_num}: Pattern match failed for '{text_cell}'")
                continue

            ilce_ad = match.group(1).strip()
            ilce_kodu = match.group(2).strip()

            try:
                cocuk = float(cocuk_cell)
                toplam = float(toplam_cell)
                yasli = float(yasli_cell)

                for val, name in [(cocuk, 'cocuk'), (toplam, 'toplam'), (yasli, 'yasli')]:
                    if math.isnan(val) or math.isinf(val) or val < 0:
                        errors.append(f"Line {line_num}: Invalid non-finite or negative {name} dependency '{val}'")
            except ValueError:
                errors.append(f"Line {line_num}: Invalid float in row {[cocuk_cell, toplam_cell, yasli_cell]}")
                continue

            if ilce_kodu in unique_codes:
                errors.append(f"Line {line_num}: Duplicate ilce_kodu '{ilce_kodu}'")
                continue

            if current_year is None:
                errors.append(f"Line {line_num}: Missing data year")
                continue

            unique_codes.add(ilce_kodu)

            records.append({
                "ilce_kodu": ilce_kodu,
                "ilce_ad": ilce_ad,
                "cocuk_bagimlilik": cocuk,
                "toplam_bagimlilik": toplam,
                "yasli_bagimlilik": yasli,
                "yil": current_year
            })

    if current_year is None:
        errors.append("CSV file contained no valid year declaration")

    return {
        "schema_version": "1.0.0",
        "data_year": current_year,
        "geographic_level": "ilce",
        "source_filename": os.path.basename(csv_path),
        "source_sha256": sha256,
        "record_count": len(records),
        "unique_ilce_codes": len(unique_codes),
        "errors": errors,
        "records": records
    }

def main():
    parser = argparse.ArgumentParser(description="Convert demography CSVs to JSON")
    parser.add_argument('--input-nufus', default='data/raw/nüfus-mahalle.csv', help='Path to population CSV')
    parser.add_argument('--input-yas', default='data/raw/yaş-mahalle.csv', help='Path to age dependency CSV')
    parser.add_argument('--output-nufus', default='assets/data/balikesir_mahalle_nufus.json', help='Output JSON path for population')
    parser.add_argument('--output-yas', default='assets/data/balikesir_ilce_demografi.json', help='Output JSON path for age dependency')
    args = parser.parse_args()

    pop_data = parse_population_csv(args.input_nufus)
    age_data = parse_age_dependency_csv(args.input_yas)

    print("=== POPULATION DATA SUMMARY ===")
    print(f"Records: {pop_data['record_count']}")
    print(f"Unique Codes: {pop_data['unique_mahalle_codes']}")
    print(f"Districts: {pop_data['district_count']}")
    print(f"Total Population: {pop_data['total_population']}")
    print(f"Errors: {len(pop_data['errors'])}")

    print("\n=== AGE DEPENDENCY SUMMARY ===")
    print(f"Records: {age_data['record_count']}")
    print(f"Unique Codes: {age_data['unique_ilce_codes']}")
    print(f"Errors: {len(age_data['errors'])}")

    if pop_data['errors'] or age_data['errors']:
        print("\nERROR: Validation failed! Refusing to write output JSON files.")
        if pop_data['errors']:
            print("Population Errors:", pop_data['errors'][:10])
        if age_data['errors']:
            print("Age Dependency Errors:", age_data['errors'][:10])
        sys.exit(1)

    os.makedirs(os.path.dirname(args.output_nufus), exist_ok=True)
    os.makedirs(os.path.dirname(args.output_yas), exist_ok=True)

    pop_output = {
        "schema_version": pop_data["schema_version"],
        "data_year": pop_data["data_year"],
        "geographic_level": pop_data["geographic_level"],
        "source_filename": pop_data["source_filename"],
        "source_sha256": pop_data["source_sha256"],
        "records": pop_data["records"]
    }

    age_output = {
        "schema_version": age_data["schema_version"],
        "data_year": age_data["data_year"],
        "geographic_level": age_data["geographic_level"],
        "source_filename": age_data["source_filename"],
        "source_sha256": age_data["source_sha256"],
        "records": age_data["records"]
    }

    with open(args.output_nufus, "w", encoding="utf-8") as f:
        json.dump(pop_output, f, ensure_ascii=False, indent=2)

    with open(args.output_yas, "w", encoding="utf-8") as f:
        json.dump(age_output, f, ensure_ascii=False, indent=2)

    print(f"\nSuccessfully written:\n  {args.output_nufus}\n  {args.output_yas}")

if __name__ == "__main__":
    main()
