/* =====================================================================
   PROJECT : CRM Customer Data Analysis - Device Analysis
   TABLES  : dbo.device1_clean, dbo.crm1_clean
   DIALECT : T-SQL (SQL Server / SSMS)
   NOTES   : - Phase 1 validates the raw table.
             - Phases 2-5 use a normalized view (trimmed, upper-cased text,
               NULLs shown as 'UNKNOWN') so spelling/casing variants
               are not counted as separate values.
             - A customer can have several device records (multiple devices,
               history, or duplicates), so "records" and "customers"
               are always reported separately.
             - imei_tac identifies a device TYPE, not a unique handset.
   ===================================================================== */


/* =====================================================================
   PHASE 1: DATA VALIDATION (raw table)
   ===================================================================== */

-- 1.1 Overall summary and missing values
-- Business question: How big is the dataset and which fields have gaps?
SELECT
    COUNT_BIG(*)                    AS Total_Records,
    COUNT_BIG(DISTINCT msisdn)      AS Unique_Customers,
    COUNT_BIG(DISTINCT imei_tac)    AS Distinct_IMEI_TAC,
    COUNT_BIG(DISTINCT brand_name)  AS Distinct_Brands,
    COUNT_BIG(DISTINCT model_name)  AS Distinct_Models,
    COUNT_BIG(DISTINCT os_name)     AS Distinct_OS,
    SUM(CASE WHEN msisdn     IS NULL THEN 1 ELSE 0 END) AS Missing_MSISDN,
    SUM(CASE WHEN imei_tac   IS NULL THEN 1 ELSE 0 END) AS Missing_IMEI_TAC,
    SUM(CASE WHEN brand_name IS NULL THEN 1 ELSE 0 END) AS Missing_Brand,
    SUM(CASE WHEN model_name IS NULL THEN 1 ELSE 0 END) AS Missing_Model,
    SUM(CASE WHEN os_name    IS NULL THEN 1 ELSE 0 END) AS Missing_OS_Name,
    SUM(CASE WHEN os_vendor  IS NULL THEN 1 ELSE 0 END) AS Missing_OS_Vendor
FROM dbo.device1_clean;


-- 1.2 Duplicate summary
-- Business question: Are identical device records repeated, and how many extra rows are there?
WITH Exact_Dupes AS (
    SELECT COUNT_BIG(*) AS Rec_Count
    FROM dbo.device1_clean
    GROUP BY msisdn, imei_tac, brand_name, model_name, os_name, os_vendor
    HAVING COUNT_BIG(*) > 1
),
Per_Customer AS (
    SELECT msisdn, COUNT_BIG(*) AS Device_Records
    FROM dbo.device1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
)
SELECT
    (SELECT COUNT_BIG(*) FROM Exact_Dupes)                      AS Groups_Of_Identical_Rows,
    (SELECT COALESCE(SUM(Rec_Count - 1), 0) FROM Exact_Dupes)   AS Extra_Identical_Rows,
    (SELECT COUNT_BIG(*) FROM Per_Customer WHERE Device_Records > 1) AS Customers_With_Multiple_Records;
-- Multiple records may mean several devices, historical records, or duplicate data.


-- 1.3 Distinct value check (look for spelling / casing variants)
SELECT DISTINCT brand_name FROM dbo.device1_clean ORDER BY brand_name;
SELECT DISTINCT os_name    FROM dbo.device1_clean ORDER BY os_name;
SELECT DISTINCT os_vendor  FROM dbo.device1_clean ORDER BY os_vendor;


-- 1.4 Incomplete device records
-- Business question: How many records and customers have incomplete device information?
SELECT
    COUNT_BIG(*)               AS Incomplete_Device_Records,
    COUNT_BIG(DISTINCT msisdn) AS Customers_With_Incomplete_Records
FROM dbo.device1_clean
WHERE imei_tac   IS NULL
   OR brand_name IS NULL
   OR model_name IS NULL
   OR os_name    IS NULL
   OR os_vendor  IS NULL;


-- 1.5 Unmatched device customers
-- Business question: Do device customer IDs exist in the CRM table?
-- ASSUMPTION: msisdn is stored in the same format in both tables.
SELECT
    COUNT_BIG(*)               AS Unmatched_Device_Records,
    COUNT_BIG(DISTINCT d.msisdn) AS Unmatched_Customers
FROM dbo.device1_clean AS d
WHERE d.msisdn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.crm1_clean AS c WHERE c.msisdn = d.msisdn
  );


/* =====================================================================
   NORMALIZED VIEW (run once, in its own batch)
   ===================================================================== */
GO
CREATE OR ALTER VIEW dbo.vw_device_normalized AS
SELECT
    msisdn,
    imei_tac,
    COALESCE(UPPER(TRIM(brand_name)), 'UNKNOWN') AS brand_name,
    COALESCE(UPPER(TRIM(model_name)), 'UNKNOWN') AS model_name,
    COALESCE(UPPER(TRIM(os_name)),    'UNKNOWN') AS os_name,
    COALESCE(UPPER(TRIM(os_vendor)),  'UNKNOWN') AS os_vendor
FROM dbo.device1_clean;
GO


/* =====================================================================
   PHASE 2: BRAND AND MODEL ANALYSIS
   ===================================================================== */

-- 2.1 Brand distribution
-- Business question: Which brands are most common, by records and by customers?
SELECT
    brand_name,
    COUNT_BIG(*)               AS Total_Records,
    COUNT_BIG(DISTINCT msisdn) AS Unique_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Records
FROM dbo.vw_device_normalized
GROUP BY brand_name
ORDER BY Total_Records DESC;
-- Pct_Of_Records is based on records, not unique customers.


-- 2.2 Top 10 device models
-- Business question: Which models appear most frequently?
SELECT TOP (10) WITH TIES
    brand_name,
    model_name,
    COUNT_BIG(*)               AS Total_Records,
    COUNT_BIG(DISTINCT msisdn) AS Unique_Customers
FROM dbo.vw_device_normalized
GROUP BY brand_name, model_name
ORDER BY Total_Records DESC;


/* =====================================================================
   PHASE 3: OPERATING SYSTEM ANALYSIS
   ===================================================================== */

-- 3.1 Operating system distribution
-- Business question: Which operating systems are most common?
SELECT
    os_name,
    COUNT_BIG(*)               AS Total_Records,
    COUNT_BIG(DISTINCT msisdn) AS Unique_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Records
FROM dbo.vw_device_normalized
GROUP BY os_name
ORDER BY Total_Records DESC;


-- 3.2 OS vendor distribution
-- Business question: Which OS vendors are most represented?
SELECT
    os_vendor,
    COUNT_BIG(*)               AS Total_Records,
    COUNT_BIG(DISTINCT msisdn) AS Unique_Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Records
FROM dbo.vw_device_normalized
GROUP BY os_vendor
ORDER BY Total_Records DESC;


-- 3.3 Brand vs operating system
-- Business question: Which operating systems are associated with each brand?
SELECT
    brand_name,
    os_name,
    COUNT_BIG(*) AS Total_Records,
    CAST(100.0 * COUNT_BIG(*) /
         SUM(COUNT_BIG(*)) OVER (PARTITION BY brand_name) AS DECIMAL(6,2)) AS Pct_Within_Brand
FROM dbo.vw_device_normalized
GROUP BY brand_name, os_name
ORDER BY brand_name, Total_Records DESC;


/* =====================================================================
   PHASE 4: CUSTOMER-DEVICE INSIGHTS
   ===================================================================== */

-- 4.1 Customers with the most device records
-- Business question: Which customer IDs have the most device records?
SELECT TOP (20) WITH TIES
    msisdn,
    COUNT_BIG(*)                 AS Device_Record_Count,
    COUNT_BIG(DISTINCT imei_tac) AS Distinct_IMEI_TAC_Count
FROM dbo.vw_device_normalized
WHERE msisdn IS NOT NULL
GROUP BY msisdn
ORDER BY Device_Record_Count DESC;
-- imei_tac identifies a device type/model, not necessarily a unique handset.


-- 4.2 Device records per customer (distribution)
-- Business question: How many customers have 1, 2, 3+ device records?
WITH Per_Customer AS (
    SELECT msisdn, COUNT_BIG(*) AS Device_Records
    FROM dbo.vw_device_normalized
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
)
SELECT
    CASE WHEN Device_Records >= 4 THEN '4+' ELSE CAST(Device_Records AS VARCHAR(5)) END AS Device_Records_Per_Customer,
    COUNT_BIG(*) AS Customers,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Customers
FROM Per_Customer
GROUP BY CASE WHEN Device_Records >= 4 THEN '4+' ELSE CAST(Device_Records AS VARCHAR(5)) END
ORDER BY MIN(Device_Records);


/* =====================================================================
   PHASE 5: ADVANCED INSIGHTS
   ===================================================================== */

-- 5.1 Brand-model-OS combinations
-- Business question: Which combinations dominate the dataset?
SELECT TOP (25)
    brand_name,
    model_name,
    os_name,
    COUNT_BIG(*) AS Total_Records
FROM dbo.vw_device_normalized
GROUP BY brand_name, model_name, os_name
ORDER BY Total_Records DESC;


-- 5.2 Brand by Prepaid vs Postpaid (joins device data to CRM)
-- Business question: Do Prepaid and Postpaid customers prefer different brands?
-- Uses distinct customers per brand to avoid double counting.
SELECT
    d.brand_name,
    COALESCE(UPPER(TRIM(c.mobile_type)), 'UNKNOWN') AS Mobile_Type,
    COUNT_BIG(DISTINCT d.msisdn)                    AS Unique_Customers
FROM dbo.vw_device_normalized AS d
JOIN dbo.crm1_clean AS c
    ON c.msisdn = d.msisdn
GROUP BY d.brand_name, COALESCE(UPPER(TRIM(c.mobile_type)), 'UNKNOWN')
ORDER BY d.brand_name, Unique_Customers DESC;
-- If crm1_clean has duplicate msisdn rows, customers can appear under more than one
-- mobile_type. Run the CRM script's duplicate check first.