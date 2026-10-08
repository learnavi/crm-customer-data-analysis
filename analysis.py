
"""
analyze_crm.py
 
Exploratory analysis of the cleaned CRM dataset (crm1_clean.csv).
 
Sections:
    1. Customer overview
    2. How often each customer appears (record frequency)
    3. System status (Active / Inactive / etc.)
    4. Mobile type (Prepaid / Postpaid)
    5. Gender
    6. Age and age groups
    7. Birth year checks
    8. Final data quality check
 
Run it like:
    python analyze_crm.py
"""
 
from datetime import datetime
 
import pandas as pd
 
INPUT_FILE = "crm1_clean.csv"
CURRENT_YEAR = datetime.now().year
 
# Customers outside this age range are treated as unreliable for age analysis
MIN_VALID_AGE = 18
MAX_VALID_AGE = 100
 
 
# ======================================================
# SMALL HELPERS (to avoid repeating the same code)
# ======================================================
 
def print_title(title):
    """Print a section heading with an underline."""
    print(f"\n{title}")
    print("-" * len(title))
 
 
def show_counts_and_percentages(series, title):
    """Show a column's counts and percentages together."""
    counts = series.value_counts()
    percentages = (counts / len(series) * 100).round(2)
 
    print_title(f"{title} (counts)")
    print(counts)
    print_title(f"{title} (%)")
    print(percentages)
 
 
def show_crosstab(row_series, col_series, title, as_percent=False):
    """Show a cross-tabulation, either as counts or as % within each row."""
    if as_percent:
        table = pd.crosstab(row_series, col_series, normalize="index") * 100
        table = table.round(2)
        title = f"{title} (%)"
    else:
        table = pd.crosstab(row_series, col_series)
        title = f"{title} (counts)"
 
    print_title(title)
    print(table)
 
 
# ======================================================
# 1. LOAD DATA
# ======================================================
 
def load_data(path):
    df = pd.read_csv(path)
 
    print_title("Dataset Overview")
    print("Shape:", df.shape)
    print("\nFirst 5 records:")
    print(df.head())
    return df
 
 
# ======================================================
# 2. CUSTOMER OVERVIEW + RECORD FREQUENCY
# ======================================================
# msisdn is the customer ID. If it appears more than once, that
# customer has multiple records -- we want to know how common that is.
 
def analyze_customers(df):
    total_records = len(df)
    unique_customers = df["msisdn"].nunique()
 
    print_title("Customer Overview")
    print("Total records:", total_records)
    print("Unique customers:", unique_customers)
 
    # How many times does each customer appear?
    records_per_customer = df["msisdn"].value_counts()
 
    print_title("Customer Record Frequency")
    print("Customers with 1 record:", (records_per_customer == 1).sum())
    print("Customers with multiple records:", (records_per_customer > 1).sum())
    print("Maximum records for one customer:", records_per_customer.max())
 
    # How many customers have 1 record, 2 records, 3 records, ...?
    distribution = records_per_customer.value_counts().sort_index()
    distribution_pct = (distribution / unique_customers * 100).round(2)
 
    print_title("Customer Record Distribution (counts)")
    print(distribution)
    print_title("Customer Record Distribution (%)")
    print(distribution_pct)
 
 
# ======================================================
# 3. SYSTEM STATUS
# ======================================================
 
def analyze_system_status(df):
    show_counts_and_percentages(df["system_status"], "System Status")
 
 
# ======================================================
# 4. MOBILE TYPE
# ======================================================
 
def analyze_mobile_type(df):
    show_counts_and_percentages(df["mobile_type"], "Mobile Type")
    show_crosstab(df["mobile_type"], df["system_status"],
                  "Status by Mobile Type")
    show_crosstab(df["mobile_type"], df["system_status"],
                  "Status by Mobile Type", as_percent=True)
 
 
# ======================================================
# 5. GENDER
# ======================================================
 
def analyze_gender(df):
    show_counts_and_percentages(df["gender"], "Gender")
    show_crosstab(df["gender"], df["system_status"],
                  "Gender vs System Status")
    show_crosstab(df["gender"], df["system_status"],
                  "Gender vs System Status", as_percent=True)
 
 
# ======================================================
# 6. AGE AND AGE GROUPS
# ======================================================
# We only analyse ages between 18 and 100. Younger/older values
# are probably data entry errors or non-standard accounts.
 
def add_age_columns(df):
    """Return a copy of df with 'age' added, plus a filtered 'valid age' table."""
    df = df.copy()
    df["age"] = CURRENT_YEAR - df["year_of_birth"]
 
    valid_age = df[(df["age"] >= MIN_VALID_AGE) &
                   (df["age"] <= MAX_VALID_AGE)].copy()
 
    # Group ages into easy-to-read brackets
    age_bins = [MIN_VALID_AGE - 1, 25, 35, 45, 55, 65, MAX_VALID_AGE]
    age_labels = ["18-25", "26-35", "36-45", "46-55", "56-65", "66-100"]
    valid_age["age_group"] = pd.cut(valid_age["age"],
                                    bins=age_bins, labels=age_labels)
    return df, valid_age
 
 
def analyze_age(valid_age):
    print_title("Valid Age Summary")
    print("Records with valid age:", len(valid_age))
    print(valid_age["age"].describe())
 
    show_counts_and_percentages(valid_age["age_group"], "Age Group")
    show_crosstab(valid_age["age_group"], valid_age["system_status"],
                  "Age Group vs System Status", as_percent=True)
 
 
# ======================================================
# 7. BIRTH YEAR CHECKS
# ======================================================
# Looking for suspicious patterns, e.g. too many customers born in
# the same year (like a default value such as 1990 or 2000).
 
def analyze_birth_years(df):
    birth_years = df["year_of_birth"].value_counts().sort_index()
 
    print_title("Earliest 20 Birth Years")
    print(birth_years.head(20))
 
    print_title("Birth Years 2000 and Later")
    print(birth_years[birth_years.index >= 2000])
 
    print_title("Top 15 Most Common Birth Years")
    print(df["year_of_birth"].value_counts().head(15))
 
 
# ======================================================
# 8. DATA QUALITY CHECK
# ======================================================
 
def data_quality_check(df):
    print_title("Missing Values")
    print(df.isnull().sum())
 
    print_title("Duplicate Records")
    print("Exact duplicates:", df.duplicated().sum())
 
    print_title("Unique Values per Category")
    for column in ["gender", "system_status", "mobile_type"]:
        print(f"{column}: {df[column].nunique()}")
 
 
# ======================================================
# MAIN
# ======================================================
 
def main():
    df = load_data(INPUT_FILE)
 
    analyze_customers(df)
    analyze_system_status(df)
    analyze_mobile_type(df)
    analyze_gender(df)
 
    df, valid_age = add_age_columns(df)
    analyze_age(valid_age)
    analyze_birth_years(df)
 
    data_quality_check(df)
 
 
if __name__ == "__main__":
    main()
 
