import os
import sys
import subprocess

def main():
    workspace = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    log_path = os.path.join(workspace, 'docs', 'step9_verification.log')
    comspec = os.environ.get('COMSPEC', r'C:\Windows\System32\cmd.exe')
    
    commands = [
        ("Python Unit Tests", 'python -m unittest discover -s scripts -p test_*.py -v'),
        ("Dart Format", 'dart format lib test'),
        ("Flutter Analyze", 'flutter analyze'),
        ("Flutter Test", 'flutter test --reporter expanded'),
        ("Flutter Build Debug APK", 'flutter build apk --debug'),
    ]

    log_lines = []
    log_lines.append("AFET ANALİZ — STEP 9 FULL VERIFICATION LOG")
    log_lines.append("===========================================")
    log_lines.append(f"Workspace: {workspace}")
    log_lines.append("")

    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    
    overall_success = True

    for name, cmd_str in commands:
        log_lines.append("==========================================")
        log_lines.append(f"COMMAND: {cmd_str}")
        log_lines.append("==========================================")
        print(f"Executing: {cmd_str}...")
        
        try:
            proc = subprocess.run(
                [comspec, '/c', cmd_str],
                cwd=workspace,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            log_lines.append(f"Exit Code: {proc.returncode}")
            log_lines.append("--- STDOUT ---")
            log_lines.append(proc.stdout)
            log_lines.append("--- STDERR ---")
            log_lines.append(proc.stderr)
            log_lines.append("")
            
            if proc.returncode != 0:
                print(f"FAILED ({proc.returncode}): {name}")
                overall_success = False
            else:
                print(f"PASSED: {name}")
        except Exception as e:
            log_lines.append(f"EXCEPTION: {str(e)}")
            log_lines.append("")
            print(f"EXCEPTION in {name}: {e}")
            overall_success = False

        # Flush log after each command
        with open(log_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(log_lines))

    print(f"\nVerification log saved to: {log_path}")
    
    apk_path = os.path.join(workspace, 'build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk')
    if os.path.exists(apk_path):
        size_bytes = os.path.getsize(apk_path)
        size_mb = size_bytes / (1024 * 1024)
        print(f"Debug APK Path: {apk_path}")
        print(f"Debug APK Size: {size_bytes} bytes ({size_mb:.2f} MB)")
    else:
        print(f"APK NOT FOUND at: {apk_path}")

    if not overall_success:
        sys.exit(1)

if __name__ == '__main__':
    main()
