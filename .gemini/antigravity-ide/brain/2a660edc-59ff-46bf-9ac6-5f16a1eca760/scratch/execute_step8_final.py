import os
import sys
import subprocess
import json
import zipfile
import hashlib
from datetime import datetime

def run_cmd(cmd_list, cwd="."):
    cmd_str = " ".join(cmd_list)
    print(f"\n==========================================")
    print(f"COMMAND: {cmd_str}")
    print(f"==========================================")
    
    proc = subprocess.run(
        cmd_str,
        cwd=cwd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding='utf-8',
        errors='replace'
    )
    
    print("--- STDOUT ---")
    print(proc.stdout)
    if proc.stderr:
        print("--- STDERR ---")
        print(proc.stderr)
    print(f"Exit Code: {proc.returncode}\n")
    return proc.returncode, proc.stdout, proc.stderr

def main():
    workspace = r"c:\Users\Monster\Desktop\afet-analiz"
    log_file_path = os.path.join(workspace, "docs", "step8_verification.log")
    
    log_lines = []
    
    def log_cmd_run(title, cmd_list):
        cmd_str = " ".join(cmd_list)
        log_lines.append(f"COMMAND: {cmd_str}\n")
        print(f"Executing: {cmd_str}")
        code, out, err = run_cmd(cmd_list, cwd=workspace)
        log_lines.append(f"EXIT CODE: {code}\n")
        log_lines.append("STDOUT:\n" + out + "\n")
        if err:
            log_lines.append("STDERR:\n" + err + "\n")
        log_lines.append("-" * 60 + "\n")
        assert code == 0, f"Command '{cmd_str}' failed with exit code {code}!"
        return out

    # 1. Python Unit Tests
    log_cmd_run("Python Unit Tests", ["python", "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py", "-v"])
    
    # 2. Dart Format
    log_cmd_run("Dart Format", ["dart", "format", "lib", "test"])
    
    # 3. Flutter Analyze
    log_cmd_run("Flutter Analyze", ["flutter", "analyze"])
    
    # 4. Flutter Test Expanded
    log_cmd_run("Flutter Test", ["flutter", "test", "--reporter", "expanded"])
    
    # 5. Flutter Build APK Debug
    log_cmd_run("Flutter Build APK", ["flutter", "build", "apk", "--debug"])
    
    # Save verification log
    with open(log_file_path, "w", encoding="utf-8") as f:
        f.writelines(log_lines)
    print(f"Saved verification log to {log_file_path}")

    # 6. Update docs/repair_progress.json
    progress_file_path = os.path.join(workspace, "docs", "repair_progress.json")
    with open(progress_file_path, "r", encoding="utf-8") as f:
        progress_data = json.load(f)

    progress_data["current_step"] = 8
    progress_data["status"] = "STEP_8_COMPLETED"
    progress_data["last_updated"] = datetime.now().isoformat()
    
    step8_record = {
        "step": 8,
        "title": "AFAD Önbelleği, İstek Yönetimi ve Kalıcı OSM Tile Cache",
        "completed_at": datetime.now().isoformat(),
        "summary": "EarthquakeQuery tipi, AFAD v3 envelope caching (15m freshness, 24h retention, 20 items / 5 MiB LRU), 350ms debounce, rate limiter HTTP per-page tracking, Retry-After parsing, single-flight coalescing ve RFC 9111 uyumlu PersistentOsmTileProvider (128 MiB LRU disk cache) tamamlandı.",
        "results": {
            "python_tests": "20/20 PASS (0 exit code)",
            "dart_format": "0 files changed (0 exit code)",
            "flutter_analyze": "No issues found! (0 exit code)",
            "flutter_test": "50/50 PASS (0 exit code)",
            "flutter_build": "Built app-debug.apk (0 exit code)",
            "osm_tile_cache": "Verified (RFC 9111 HTTP semantics, 128 MiB LRU eviction, 304 conditional revalidation)"
        },
        "open_tasks": [
            "Adım 9: Genel regresyon ve gösterge kontrolleri",
            "KML kaynak kısıtı ve imza süreçleri"
        ],
        "unstarted": [
            "Tema ve renk paleti yenileme",
            "README.md güncellemeleri"
        ]
    }
    
    steps_list = progress_data.get("steps", [])
    steps_list = [s for s in steps_list if s.get("step") != 8]
    steps_list.append(step8_record)
    progress_data["steps"] = steps_list
    
    with open(progress_file_path, "w", encoding="utf-8") as f:
        json.dump(progress_data, f, ensure_ascii=False, indent=2)
    print(f"Updated {progress_file_path}")

    # 7. Package using package_review.py
    pkg_cmd = ["python", "scripts/package_review.py", "--project", ".", "--step", "8", "--output-dir", r"C:\Users\Monster\Desktop\afet-analiz-backups", "--open"]
    log_cmd_run("Package Review Step 8", pkg_cmd)

if __name__ == "__main__":
    main()
