
import pandas as pd

INPUT_FILE = "crm1.csv"
OUTPUT_FILE = "crm1_clean.csv"


# ======================================================
# STEP 1: LOAD DATA
# ======================================================

def load_data(path):
    print(f"Loading {path} ...")
    df = pd.read_csv(path)
    print(f"Loaded {len(df):,} rows and {len(df.columns)} columns\n")
    return df


# ======================================================
# STEP 2: CLEAN GENDER
# ======================================================
# The raw data has dozens of inconsistent spellings for Male/Female
# (typos, stray punctuation, random extra letters). We fix the ones
# we can confidently recognize, and mark anything else as UNKNOWN
# rather than guessing.

MALE_VALUES = [
    "MALE", "MAL", "MALE.", "MALE`", "MALEF", "MAFELE", "MFEALE", "MALFEe"
]

FEMALE_VALUES = [
    "FEMALE", "FEMALE.", "FEMALE]", "FEMALE3", "FEMALE`", "FEMALEH",
    "FEMALEF", "FEMALE\\", "FEMALE..", "FEMAL", "FEMAL]E", "FEMELE",
    "FEMEL", "FAMALE", "FEMAL"
]


def clean_gender(df):
    print("Cleaning 'gender' column...")

    # Normalize formatting first: strip spaces, make uppercase,
    # so "male ", "Male", "MALE" all become comparable.
    df["gender"] = df["gender"].astype("string").str.strip().str.upper()

    # Fix known Male/Female variants
    df.loc[df["gender"].isin(MALE_VALUES), "gender"] = "MALE"
    df.loc[df["gender"].isin(FEMALE_VALUES), "gender"] = "FEMALE"

    # Anything we don't recognize becomes UNKNOWN (never guessed)
    df.loc[~df["gender"].isin(["MALE", "FEMALE"]), "gender"] = "UNKNOWN"

    print("Gender distribution after cleaning:")
    print(df["gender"].value_counts(dropna=False))
    print()
    return df


# ======================================================
# STEP 3: CLEAN YEAR OF BIRTH
# ======================================================
# Birth years outside a realistic human range (1900-2026) are
# data errors, not real customers. We treat them as missing
# rather than deleting the whole row.

def clean_year_of_birth(df):
    print("Cleaning 'year_of_birth' column...")

    before_missing = df["year_of_birth"].isna().sum()

    invalid = (df["year_of_birth"] < 1900) | (df["year_of_birth"] > 2026)
    df.loc[invalid, "year_of_birth"] = pd.NA

    # Use a nullable integer type so missing years stay as <NA>, not NaN float
    df["year_of_birth"] = df["year_of_birth"].astype("Int64")

    after_missing = df["year_of_birth"].isna().sum()

    print(f"Missing before cleaning: {before_missing:,}")
    print(f"Missing after cleaning (includes invalid years): {after_missing:,}")
    print(df["year_of_birth"].describe())
    print()
    return df


# ======================================================
# STEP 4: HANDLE DUPLICATES
# ======================================================
# Two kinds of duplicates to deal with:
#   - exact duplicate rows -> safe to just drop
#   - same customer (msisdn) appearing multiple times with
#     different data -> worth inspecting before deciding what to do

def investigate_duplicate_customers(df):
    print("Investigating duplicate customers (msisdn)...")

    msisdn_counts = df["msisdn"].value_counts()
    repeated = (msisdn_counts > 1).sum()

    print(f"Unique msisdn: {df['msisdn'].nunique():,}")
    print(f"msisdn appearing more than once: {repeated:,}")
    print(f"msisdn appearing more than 5 times: {(msisdn_counts > 5).sum():,}")

    if repeated > 0:
        example_id = msisdn_counts[msisdn_counts > 1].index[0]
        print(f"\nExample duplicate customer ({example_id}):")
        print(df[df["msisdn"] == example_id].to_string(index=False))
    print()


def remove_exact_duplicates(df):
    before = df.duplicated().sum()
    df = df.drop_duplicates()
    print(f"Removed {before:,} exact duplicate rows")
    print(f"Shape after removing duplicates: {df.shape}\n")
    return df


# ======================================================
# STEP 5: CHECK OTHER CATEGORICAL COLUMNS
# ======================================================

def check_categorical_columns(df):
    for col in ["system_status", "mobile_type", "value_segment"]:
        print(f"'{col}' distribution:")
        print(df[col].value_counts(dropna=False))
        print()


# ======================================================
# STEP 6: DROP COLUMNS THAT DON'T ADD VALUE
# ======================================================
# value_segment turned out to be a single constant value across
# the whole dataset (e.g. always "Tier_3") -- it can't explain any
# variation in the analysis, so it's dead weight. Drop it.

def drop_useless_columns(df):
    if df["value_segment"].nunique() <= 1:
        df = df.drop(columns=["value_segment"])
        print("Dropped 'value_segment' (only one unique value, adds no signal)\n")
    return df


# ======================================================
# STEP 7: FINAL QUALITY CHECK
# ======================================================

def final_quality_check(df):
    print("========== FINAL DATA QUALITY CHECK ==========")
    print(f"\nFinal shape: {df.shape}")
    print(f"\nMissing values:\n{df.isna().sum()}")
    print(f"\nDuplicate rows: {df.duplicated().sum()}")
    print(f"\nData types:\n{df.dtypes}")
    print(f"\nPreview:\n{df.head()}")


# ======================================================
# MAIN
# ======================================================

def main():
    df = load_data(INPUT_FILE)

    df = clean_gender(df)
    df = clean_year_of_birth(df)

    investigate_duplicate_customers(df)
    df = remove_exact_duplicates(df)

    check_categorical_columns(df)
    df = drop_useless_columns(df)

    final_quality_check(df)

    df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nSaved cleaned file to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()