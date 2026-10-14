
"""
clean_rev1.py
Cleans rev1.csv (one row per customer per week)
and builds a one-row-per-customer summary.
"""

from pathlib import Path
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent

INPUT_FILE = BASE_DIR / "data" / "raw" / "rev1.csv"
WEEKLY_OUTPUT = BASE_DIR / "data" / "processed" / "rev1_clean.csv"
SUMMARY_OUTPUT = BASE_DIR / "data" / "processed" / "revenue_customer_summary.csv"



def main():
    # 1. Load original dataset
    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input file not found: {INPUT_FILE}\n"
            "Make sure rev1.csv is inside your project folder."
        )

    df = pd.read_csv(INPUT_FILE)
    rows_before = len(df)

    print("Original shape:", df.shape)

    # 2. Check required columns
    required = ["msisdn", "week_number", "revenue_usd"]

    missing_columns = [col for col in required if col not in df.columns]
    if missing_columns:
        raise ValueError(f"Missing columns: {missing_columns}")

    # 3. Clean customer IDs
    df["msisdn"] = df["msisdn"].astype("string").str.strip()

    # Convert numeric columns safely
    df["week_number"] = pd.to_numeric(
        df["week_number"], errors="coerce"
    )
    df["revenue_usd"] = pd.to_numeric(
        df["revenue_usd"], errors="coerce"
    )

    # 4. Validate required values
    assert df[required].notna().all().all(), (
        "Missing or invalid values found in required columns"
    )

    assert not df.duplicated(["msisdn", "week_number"]).any(), (
        "Duplicate customer-week rows found"
    )

    assert (df["revenue_usd"] >= 0).all(), (
        "Negative revenue found"
    )

    # 5. Correct data types and precision
    df["week_number"] = df["week_number"].astype("int64")
    df["revenue_usd"] = df["revenue_usd"].astype("float64").round(4)

    # 6. Sort weekly records
    df = df.sort_values(["msisdn", "week_number"])

    # 7. Create customer-level summary
    summary = (
        df.groupby("msisdn")
        .agg(
            total_revenue_usd=("revenue_usd", "sum"),
            avg_weekly_revenue_usd=("revenue_usd", "mean"),
            active_weeks=("week_number", "nunique")
        )
        .round(2)
        .reset_index()
    )

    # 8. Save output files
    df.to_csv(WEEKLY_OUTPUT, index=False)
    summary.to_csv(SUMMARY_OUTPUT, index=False)

    # 9. Display results
    print("\nCleaning completed successfully!")
    print(f"Rows before: {rows_before:,}")
    print(f"Rows after: {len(df):,}")
    print(f"Unique customers: {df['msisdn'].nunique():,}")
    print(
        f"Weeks covered: {df['week_number'].min()} "
        f"to {df['week_number'].max()}"
    )
    print(f"Summary rows: {len(summary):,}")
    print(f"\nSaved weekly data: {WEEKLY_OUTPUT}")
    print(f"Saved customer summary: {SUMMARY_OUTPUT}")


if __name__ == "__main__":
    main()
