/* =====================================================================
   PROJECT : CRM Customer Analysis
   TABLE   : dbo.crm1_clean
   DIALECT : T-SQL (SQL Server)
   NOTES   : - Phase 1 validates the raw table (record level).
             - Phases 2-4 use a deduplicated view (customer level).
             - Age is approximate (birth year only).
   ===================================================================== */


/* =====================================================================
   PHASE 1: DATA VALIDATION
   ===================================================================== */

-- 1.1 Data quality snapshot
-- Business question: How many records and unique customers do we have, and what is missing?
SELECT
    COUNT_BIG(*)                                                AS Total_Records,
    COUNT_BIG(DISTINCT msisdn)                                  AS Unique_Customers,
    SUM(CASE WHEN msisdn        IS NULL THEN 1 ELSE 0 END)      AS Missing_MSISDN,
    SUM(CASE WHEN gender        IS NULL THEN 1 ELSE 0 END)      AS Missing_Gender,
    SUM(CASE WHEN year_of_birth IS NULL THEN 1 ELSE 0 END)      AS Missing_Birth_Year,
    SUM(CASE WHEN system_status IS NULL THEN 1 ELSE 0 END)      AS Missing_Status,
    SUM(CASE WHEN mobile_type   IS NULL THEN 1 ELSE 0 END)      AS Missing_Mobile_Type,
    CAST(100.0 * SUM(CASE WHEN year_of_birth IS NULL THEN 1 ELSE 0 END)
         / COUNT_BIG(*) AS DECIMAL(5,2))                        AS Missing_Birth_Year_Pct
FROM dbo.crm1_clean;


-- 1.2 Duplicate summary
-- Business question: How many customers have multiple records, and are any rows fully identical?
WITH Per_Customer AS (
    SELECT msisdn, COUNT_BIG(*) AS Rec_Count
    FROM dbo.crm1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
),
Exact_Dupes AS (
    SELECT COUNT_BIG(*) AS Rec_Count
    FROM dbo.crm1_clean
    GROUP BY msisdn, gender, year_of_birth, system_status, mobile_type
    HAVING COUNT_BIG(*) > 1
)
SELECT
    (SELECT COUNT_BIG(*) FROM Per_Customer WHERE Rec_Count > 1) AS Customers_With_Multiple_Records,
    (SELECT COUNT_BIG(*) FROM Exact_Dupes)                      AS Groups_Of_Identical_Rows,
    (SELECT COALESCE(SUM(Rec_Count - 1), 0) FROM Exact_Dupes)   AS Extra_Identical_Rows_To_Remove;


-- 1.3 Distinct value check (spot spelling / casing variants before grouping)
SELECT DISTINCT system_status FROM dbo.crm1_clean;
SELECT DISTINCT gender        FROM dbo.crm1_clean;
SELECT DISTINCT mobile_type   FROM dbo.crm1_clean;


-- 1.4 MSISDN validity check
-- Business question: Do customer IDs have a consistent format?
SELECT
    LEN(msisdn)  AS MSISDN_Length,
    COUNT_BIG(*) AS Total_Records,
    SUM(CASE WHEN msisdn LIKE '%[^0-9]%' THEN 1 ELSE 0 END) AS Non_Numeric_Records
FROM dbo.crm1_clean
WHERE msisdn IS NOT NULL
GROUP BY LEN(msisdn)
ORDER BY Total_Records DESC;


/* =====================================================================
   DEDUPLICATED CUSTOMER VIEW (run once, in its own batch)
   ASSUMPTION: no timestamp column exists, so the kept record is arbitrary.
   If you have a last-updated date, replace ORDER BY (SELECT NULL)
   with ORDER BY <date_column> DESC.
   ===================================================================== */
GO
CREATE OR ALTER VIEW dbo.vw_crm_customers AS
SELECT msisdn, gender, year_of_birth, system_status, mobile_type
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY msisdn ORDER BY (SELECT NULL)) AS rn
    FROM dbo.crm1_clean
    WHERE msisdn IS NOT NULL
) AS x
WHERE rn = 1;
GO


/* =====================================================================
   PHASE 2: CUSTOMER PROFILE (customer level)
   ===================================================================== */

-- 2.1 Gender distribution
-- Business question: What is the gender composition of the customer base?
SELECT
    COALESCE(UPPER(TRIM(gender)), 'UNKNOWN') AS Gender,
    COUNT_BIG(*)                             AS Total_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(5,2)) AS Pct_Of_Customers
FROM dbo.vw_crm_customers
GROUP BY COALESCE(UPPER(TRIM(gender)), 'UNKNOWN')
ORDER BY Total_Customers DESC;


-- 2.2 System status
-- Business question: What share of customers are Active, Suspended, Idle or Deactivated?
SELECT
    COALESCE(UPPER(TRIM(system_status)), 'UNKNOWN') AS System_Status,
    COUNT_BIG(*)                                    AS Total_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(5,2)) AS Pct_Of_Customers
FROM dbo.vw_crm_customers
GROUP BY COALESCE(UPPER(TRIM(system_status)), 'UNKNOWN')
ORDER BY Total_Customers DESC;


-- 2.3 Prepaid vs Postpaid
-- Business question: Which mobile service type has more customers?
SELECT
    COALESCE(UPPER(TRIM(mobile_type)), 'UNKNOWN') AS Mobile_Type,
    COUNT_BIG(*)                                  AS Total_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(5,2)) AS Pct_Of_Customers
FROM dbo.vw_crm_customers
GROUP BY COALESCE(UPPER(TRIM(mobile_type)), 'UNKNOWN')
ORDER BY Total_Customers DESC;


-- 2.4 Status by mobile type
-- Business question: Does the status distribution differ between Prepaid and Postpaid?
SELECT
    COALESCE(UPPER(TRIM(mobile_type)), 'UNKNOWN')   AS Mobile_Type,
    COALESCE(UPPER(TRIM(system_status)), 'UNKNOWN') AS System_Status,
    COUNT_BIG(*)                                    AS Total_Customers,
    CAST(100.0 * COUNT_BIG(*) /
         SUM(COUNT_BIG(*)) OVER (PARTITION BY COALESCE(UPPER(TRIM(mobile_type)), 'UNKNOWN'))
         AS DECIMAL(5,2))                           AS Pct_Within_Mobile_Type
FROM dbo.vw_crm_customers
GROUP BY COALESCE(UPPER(TRIM(mobile_type)), 'UNKNOWN'),
         COALESCE(UPPER(TRIM(system_status)), 'UNKNOWN')
ORDER BY Mobile_Type, Total_Customers DESC;


/* =====================================================================
   PHASE 3: AGE ANALYSIS
   Missing birth years are reported as 'Unknown'; out-of-range years as 'Invalid'.
   ===================================================================== */

-- 3.1 Birth year range
-- Business question: Are any birth years outside a reasonable range?
SELECT
    MIN(year_of_birth) AS Earliest_Birth_Year,
    MAX(year_of_birth) AS Latest_Birth_Year,
    COUNT_BIG(*)       AS Records_With_Birth_Year
FROM dbo.vw_crm_customers
WHERE year_of_birth IS NOT NULL;


-- 3.2 Age group distribution
-- Business question: Which age groups make up the largest share of customers?
WITH Ages AS (
    SELECT
        CASE
            WHEN year_of_birth IS NULL                              THEN 'Unknown'
            WHEN year_of_birth NOT BETWEEN 1900 AND YEAR(GETDATE()) THEN 'Invalid'
            ELSE CASE
                WHEN YEAR(GETDATE()) - year_of_birth < 18  THEN 'Under 18'
                WHEN YEAR(GETDATE()) - year_of_birth <= 25 THEN '18-25'
                WHEN YEAR(GETDATE()) - year_of_birth <= 35 THEN '26-35'
                WHEN YEAR(GETDATE()) - year_of_birth <= 45 THEN '36-45'
                WHEN YEAR(GETDATE()) - year_of_birth <= 60 THEN '46-60'
                ELSE 'Above 60'
            END
        END AS Age_Group
    FROM dbo.vw_crm_customers
)
SELECT
    Age_Group,
    COUNT_BIG(*) AS Total_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(5,2)) AS Pct
FROM Ages
GROUP BY Age_Group
ORDER BY CASE Age_Group
    WHEN 'Under 18' THEN 1 WHEN '18-25' THEN 2 WHEN '26-35' THEN 3
    WHEN '36-45'    THEN 4 WHEN '46-60' THEN 5 WHEN 'Above 60' THEN 6
    WHEN 'Invalid'  THEN 7 ELSE 8 END;


/* =====================================================================
   PHASE 4: ADVANCED CUSTOMER ANALYSIS (raw table, record level)
   ===================================================================== */

-- 4.1 Customers with the most records
-- Business question: Which customer IDs appear most frequently?
SELECT TOP (20) WITH TIES
    msisdn,
    COUNT_BIG(*) AS Record_Count
FROM dbo.crm1_clean
WHERE msisdn IS NOT NULL
GROUP BY msisdn
HAVING COUNT_BIG(*) > 1
ORDER BY Record_Count DESC;


-- 4.2 Records vs unique customers
-- Business question: How much does the raw record count exceed unique customers?
SELECT
    COUNT_BIG(*)                                                  AS Total_Records,
    COUNT_BIG(DISTINCT msisdn)                                    AS Unique_Customers,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT msisdn)                     AS Extra_Records_Beyond_Unique_Customers
FROM dbo.crm1_clean;