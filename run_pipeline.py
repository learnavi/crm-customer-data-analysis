
import subprocess
import sys
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# CHANGE 1: Use the actual scripts folder
SCRIPTS_DIR = BASE_DIR / "scripts"

# CHANGE 2: Use your actual script filenames
SCRIPTS = [
    "clean_crm.py",
    "clean_rev1.py",
    "clean_device1.py",
]


def check_scripts_exist():
    missing = [
        name for name in SCRIPTS
        if not (SCRIPTS_DIR / name).is_file()
    ]

    if missing:
        print(f"ERROR: Scripts not found in {SCRIPTS_DIR}")
        for name in missing:
            print(f"  - {name}")
        sys.exit(1)


def run_script(name):
    script_path = SCRIPTS_DIR / name

    print(f"\nRunning: {name}")
    start = time.perf_counter()

    result = subprocess.run(
        [sys.executable, str(script_path)],
        cwd=BASE_DIR
    )

    elapsed = time.perf_counter() - start

    if result.returncode != 0:
        print(f"FAILED: {name}")
        print("Pipeline stopped because this script failed.")
        sys.exit(result.returncode)

    print(f"SUCCESS: {name} ({elapsed:.1f} seconds)")


def main():
    print("=" * 50)
    print("STARTING DATA CLEANING PIPELINE")
    print("=" * 50)

    check_scripts_exist()

    pipeline_start = time.perf_counter()

    for script in SCRIPTS:
        run_script(script)

    total_time = time.perf_counter() - pipeline_start

    print("\n" + "=" * 50)
    print("ALL SCRIPTS COMPLETED SUCCESSFULLY")
    print(f"Total time: {total_time:.1f} seconds")
    print("=" * 50)


if __name__ == "__main__":
    main()
