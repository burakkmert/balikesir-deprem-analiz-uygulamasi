import os
import sys
import glob
import json
import hashlib
import zipfile
import datetime
import subprocess

base_dir = r"c:\Users\Monster\Desktop\afet-analiz"
backup_dir = r"C:\Users\Monster\Desktop\afet-analiz-backups"

print(f"1. VERIFYING WORKSPACE: {base_dir}")
pubspec_path = os.path.join(base_dir, "pubspec.yaml")
lib_dir = os.path.join(base_dir, "lib")

assert os.path.isfile(pubspec_path), f"pubspec.yaml not found at {pubspec_path}"
assert os.path.isdir(lib_dir), f"lib directory not found at {lib_dir}"
print("  pubspec.yaml and lib/ verified successfully.")

# Check backup directory
os.makedirs(backup_dir, exist_ok=True)
print(f"  Backup directory confirmed: {backup_dir}")

# Check if previous step6_acceptance_review.zip exists
old_zip = os.path.join(backup_dir, "step6_acceptance_review.zip")
old_zip_exists = os.path.exists(old_zip)
print(f"  Check step6_acceptance_review.zip existence: {old_zip_exists}")
if old_zip_exists:
    print(f"    Existing ZIP size: {os.path.getsize(old_zip)} bytes")

# 2. CREATE TIMESTAMPED ZIP
now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
zip_name = f"step6_acceptance_review_{now_str}.zip"
zip_path = os.path.join(backup_dir, zip_name)
print(f"\n2. CREATING NEW ZIP: {zip_path}")

# List of required explicit files and directories to include
include_dirs = ["lib", "scripts", "test", "assets/data", "docs"]
include_files = ["pubspec.yaml", "pubspec.lock", "analysis_options.yaml"]

# Check required files exist
req_docs = [
    os.path.join(base_dir, "docs", "repair_progress.json"),
    os.path.join(base_dir, "docs", "step6_acceptance_verification.log")
]
for rf in req_docs:
    assert os.path.isfile(rf), f"Required document missing: {rf}"

prohibited_patterns = [
    "data/raw", "build", ".dart_tool", ".gradle", ".git", "__pycache__",
    ".env", "local.properties", "key.properties"
]
prohibited_exts = [".pyc", ".jks", ".keystore", ".zip"]

packaged_files = []

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    # 1. Include explicit files
    for f in include_files:
        full_f = os.path.join(base_dir, f)
        if os.path.isfile(full_f):
            zf.write(full_f, f)
            packaged_files.append(f)
            
    # 2. Include directories
    for d in include_dirs:
        full_d = os.path.join(base_dir, d)
        if os.path.isdir(full_d):
            for root, dirs, files in os.walk(full_d):
                rel_root = os.path.relpath(root, base_dir)
                
                # Filter out prohibited directories
                if any(p in rel_root.replace("\\", "/") for p in prohibited_patterns):
                    continue
                    
                for file in files:
                    if file.startswith(".env") or file.startswith(".git"):
                        continue
                    if any(file.endswith(ext) for ext in prohibited_exts):
                        continue
                        
                    file_path = os.path.join(root, file)
                    rel_path = os.path.relpath(file_path, base_dir)
                    
                    zf.write(file_path, rel_path)
                    packaged_files.append(rel_path)

zip_bytes = os.path.getsize(zip_path)
print(f"  Zip file created successfully. Size: {zip_bytes} bytes ({zip_bytes/(1024*1024):.2f} MB)")
print(f"  Total items archived: {len(packaged_files)}")

# 3. RIGOROUS VERIFICATION
print(f"\n3. VERIFYING ARCHIVE INTEGRITY AND SHA-256 MATCHING")

# A. File exists and size > 0
assert os.path.exists(zip_path), f"Zip file missing: {zip_path}"
assert zip_bytes > 0, "Zip file byte size is 0!"

# B. zipfile.testzip() check
with zipfile.ZipFile(zip_path, "r") as zf:
    corrupt = zf.testzip()
    assert corrupt is None, f"Zip testzip failed, corrupt file: {corrupt}"
    print("  zipfile.testzip() integrity check: PASSED (None)")
    
    zip_namelist = set(zf.namelist())
    
    # C. Verify no prohibited files inside zip
    for name in zip_namelist:
        norm_name = name.replace("\\", "/")
        for p in prohibited_patterns:
            assert p not in norm_name, f"Prohibited pattern '{p}' found in zip entry: {name}"
        for ext in prohibited_exts:
            assert not norm_name.endswith(ext), f"Prohibited extension '{ext}' found in zip entry: {name}"
    print("  Prohibited files check: PASSED (None found)")
    
    # D. SHA-256 verification of packaged files
    sha_matches = 0
    for name in zip_namelist:
        local_fp = os.path.join(base_dir, name)
        assert os.path.isfile(local_fp), f"Packaged file not found in workspace: {local_fp}"
        
        with open(local_fp, "rb") as f:
            local_sha = hashlib.sha256(f.read()).hexdigest()
            
        zip_data = zf.read(name)
        zip_sha = hashlib.sha256(zip_data).hexdigest()
        
        assert local_sha == zip_sha, f"SHA-256 mismatch for file {name}! Local: {local_sha}, Zip: {zip_sha}"
        sha_matches += 1
        
    print(f"  SHA-256 matching check: PASSED ({sha_matches}/{len(zip_namelist)} files match 100%)")

# E. Verify no required source files were omitted from the zip
expected_workspace_files = []
for d in include_dirs:
    full_d = os.path.join(base_dir, d)
    for root, dirs, files in os.walk(full_d):
        rel_root = os.path.relpath(root, base_dir)
        if any(p in rel_root.replace("\\", "/") for p in prohibited_patterns):
            continue
        for file in files:
            if file.startswith(".env") or file.startswith(".git") or any(file.endswith(ext) for ext in prohibited_exts):
                continue
            expected_workspace_files.append(os.path.relpath(os.path.join(root, file), base_dir))

for f in include_files:
    expected_workspace_files.append(f)

missing_in_zip = set(expected_workspace_files) - set(packaged_files)
assert len(missing_in_zip) == 0, f"Source files omitted from ZIP: {missing_in_zip}"
print(f"  Omission check: PASSED (All {len(expected_workspace_files)} expected workspace files packaged)")

# 4. SHOW FILE IN WINDOWS EXPLORER
print(f"\n4. OPENING FILE IN WINDOWS EXPLORER")
explorer_cmd = f'explorer.exe /select,"{zip_path}"'
subprocess.Popen(explorer_cmd, shell=True)
print(f"  Explorer opened for {zip_path}")

print(f"\nFINAL_RESULTS_JSON:")
results = {
    "zip_path": zip_path,
    "zip_bytes": zip_bytes,
    "file_count": len(packaged_files),
    "old_zip_existed": old_zip_exists,
    "testzip_passed": True,
    "sha256_passed": True,
    "omission_check_passed": True
}
print(json.dumps(results, indent=2))
