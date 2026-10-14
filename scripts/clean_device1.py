
"""
clean_devie1.py
Cleans device1.csv (one row per customer per device).
"""
from pathlib import Path
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent

INPUT_FILE = BASE_DIR / "data" / "raw" / "device1.csv"
OUTPUT_FILE = BASE_DIR / "data" / "processed" / "device1_clean.csv"

TEXT_COLUMNS = [
    "msisdn",
    "imei_tac",
    "brand_name",
    "model_name",
    "os_name",
    "os_vendor"
]

CATEGORY_COLUMNS = [
    "brand_name",
    "model_name",
    "os_name",
    "os_vendor"
]


def main():
    # 1. Load dataset
    df = pd.read_csv(INPUT_FILE, dtype={"imei_tac": "string"})
    rows_before = len(df)

    print("Original shape:", df.shape)

    # 2. Remove extra spaces from text columns
    for col in TEXT_COLUMNS:
        if col in df.columns:
            df[col] = df[col].str.strip()

    # 3. Standardise brand and model names
    if "brand_name" in df.columns:
        df["brand_name"] = df["brand_name"].str.upper()

    if "model_name" in df.columns:
        df["model_name"] = df["model_name"].str.upper()

    # 4. Handle missing category values
    for col in CATEGORY_COLUMNS:
        if col in df.columns:
            df[col] = df[col].replace("", pd.NA).fillna("UNKNOWN")

    # 5. Validate required columns
    for col in ["msisdn", "imei_tac"]:
        assert col in df.columns, f"Required column missing: {col}"
        assert df[col].notna().all(), f"Missing values found in {col}"

    # 6. Remove exact duplicate rows only
    df = df.drop_duplicates()

    # 7. Save cleaned dataset
    df.to_csv(OUTPUT_FILE, index=False)

    print("\nCleaning completed successfully!")
    print(f"Rows before: {rows_before:,}")
    print(f"Rows after: {len(df):,}")
    print(f"Duplicate rows removed: {rows_before - len(df):,}")

    if "brand_name" in df.columns:
        print(f"Distinct brands: {df['brand_name'].nunique():,}")

    print("\nMissing values after cleaning:")
    print(df.isna().sum())

    print(f"\nSaved to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
