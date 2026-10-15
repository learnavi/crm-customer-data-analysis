/* =====================================================================
   PROJECT : CRM Customer Data Analysis - Revenue Analysis
   TABLE   : dbo.rev1_clean   (msisdn, week_number, revenue_usd)
   DIALECT : T-SQL (SQL Server / SSMS)
   NOTES   : - Data quality is checked first, because bad revenue values
               (NULL, negative, duplicated) distort every later total.
             - Section 5 needs dbo.vw_crm_customers from the CRM script.
               Run that script's view step first.
   ===================================================================== */


/* =====================================================================
   1. DATA QUALITY CHECKS
   ===================================================================== */

-- 1.1 Preview the data
SELECT TOP (10) * FROM dbo.rev1_clean;


-- 1.2 Missing, zero and negative values
-- Business question: Is the revenue data clean enough to total?
SELECT
    COUNT_BIG(*)                                              AS Total_Records,
    SUM(CASE WHEN msisdn      IS NULL THEN 1 ELSE 0 END)      AS Missing_MSISDN,
    SUM(CASE WHEN week_number IS NULL THEN 1 ELSE 0 END)      AS Missing_Week,
    SUM(CASE WHEN revenue_usd IS NULL THEN 1 ELSE 0 END)      AS Missing_Revenue,
    SUM(CASE WHEN revenue_usd = 0     THEN 1 ELSE 0 END)      AS Zero_Revenue_Records,
    SUM(CASE WHEN revenue_usd < 0     THEN 1 ELSE 0 END)      AS Negative_Revenue_Records
FROM dbo.rev1_clean;


-- 1.3 Duplicate customer-week records
-- Business question: Does any customer appear more than once in the same week?
SELECT TOP (50)
    msisdn,
    week_number,
    COUNT_BIG(*)         AS Record_Count,
    SUM(revenue_usd)     AS Combined_Revenue
FROM dbo.rev1_clean
GROUP BY msisdn, week_number
HAVING COUNT_BIG(*) > 1
ORDER BY Record_Count DESC;

-- Summary version: how many customer-weeks are affected?
SELECT
    COUNT_BIG(*)                  AS Duplicated_Customer_Weeks,
    COALESCE(SUM(Rec_Count - 1), 0) AS Extra_Records
FROM (
    SELECT COUNT_BIG(*) AS Rec_Count
    FROM dbo.rev1_clean
    GROUP BY msisdn, week_number
    HAVING COUNT_BIG(*) > 1
) AS D;
-- Duplicates could be real (several charges in a week) or load errors.
-- Check before removing anything.


/* =====================================================================
   2. OVERALL REVENUE SUMMARY
   ===================================================================== */

-- 2.1 Headline numbers
-- Business question: How much revenue is there, and what is a typical record worth?
-- Note: SUM/AVG ignore NULLs. AVG is per record, not per customer.
SELECT
    COUNT_BIG(*)                         AS Total_Records,
    COUNT_BIG(DISTINCT msisdn)           AS Unique_Customers,
    COUNT_BIG(DISTINCT week_number)      AS Weeks_Covered,
    SUM(revenue_usd)                     AS Total_Revenue_USD,
    CAST(AVG(revenue_usd) AS DECIMAL(18,2)) AS Avg_Revenue_Per_Record,
    MIN(revenue_usd)                     AS Min_Revenue,
    MAX(revenue_usd)                     AS Max_Revenue
FROM dbo.rev1_clean;


/* =====================================================================
   3. CUSTOMER-LEVEL REVENUE
   ===================================================================== */

-- 3.1 Top 10 revenue-generating customers
-- Business question: Which customers generate the most revenue?
WITH Customer_Revenue AS (
    SELECT msisdn, SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
)
SELECT TOP (10) WITH TIES
    msisdn,
    Total_Revenue,
    CAST(100.0 * Total_Revenue / SUM(Total_Revenue) OVER () AS DECIMAL(6,3)) AS Pct_Of_Total_Revenue
FROM Customer_Revenue
ORDER BY Total_Revenue DESC;


-- 3.2 Average revenue per customer
-- Business question: What is the average customer worth over the whole period?
SELECT
    COUNT_BIG(*)                                      AS Customers,
    CAST(AVG(Customer_Revenue) AS DECIMAL(18,2))      AS Avg_Revenue_Per_Customer,
    MIN(Customer_Revenue)                             AS Min_Customer_Revenue,
    MAX(Customer_Revenue)                             AS Max_Customer_Revenue
FROM (
    SELECT msisdn, SUM(revenue_usd) AS Customer_Revenue
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
) AS Customer_Summary;


-- 3.3 Revenue concentration by customer decile
-- Business question: How much revenue comes from the top 10% of customers?
-- Decile 1 = highest-revenue 10% of customers.
WITH Customer_Revenue AS (
    SELECT msisdn, SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
),
Ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY Total_Revenue DESC) AS Decile
    FROM Customer_Revenue
)
SELECT
    Decile,
    COUNT_BIG(*)         AS Customers,
    SUM(Total_Revenue)   AS Revenue,
    CAST(100.0 * SUM(Total_Revenue) / SUM(SUM(Total_Revenue)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Total_Revenue
FROM Ranked
GROUP BY Decile
ORDER BY Decile;


/* =====================================================================
   4. WEEKLY REVENUE TREND
   ===================================================================== */

-- 4.1 Weekly revenue, customers, revenue per customer and week-over-week change
-- Business question: How is revenue trending, and is it driven by more customers or higher spend?
WITH Weekly AS (
    SELECT
        week_number,
        COUNT_BIG(*)                AS Records,
        COUNT_BIG(DISTINCT msisdn)  AS Active_Customers,
        SUM(revenue_usd)            AS Weekly_Revenue
    FROM dbo.rev1_clean
    GROUP BY week_number
)
SELECT
    week_number,
    Records,
    Active_Customers,
    Weekly_Revenue,
    CAST(Weekly_Revenue / NULLIF(Active_Customers, 0) AS DECIMAL(18,2)) AS Revenue_Per_Customer,
    CAST(100.0 * (Weekly_Revenue - LAG(Weekly_Revenue) OVER (ORDER BY week_number))
         / NULLIF(LAG(Weekly_Revenue) OVER (ORDER BY week_number), 0) AS DECIMAL(8,2)) AS WoW_Revenue_Change_Pct
FROM Weekly
ORDER BY week_number;


/* =====================================================================
   5. REVENUE BY CUSTOMER SEGMENT (joins to CRM)
   Requires dbo.vw_crm_customers (one row per customer).
   ===================================================================== */

-- 5.1 Revenue by Prepaid vs Postpaid
-- Business question: Which service type generates more revenue per customer?
WITH Customer_Revenue AS (
    SELECT msisdn, SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
)
SELECT
    COALESCE(UPPER(TRIM(c.mobile_type)), 'UNKNOWN') AS Mobile_Type,
    COUNT_BIG(*)                                    AS Customers,
    SUM(r.Total_Revenue)                            AS Total_Revenue,
    CAST(AVG(r.Total_Revenue) AS DECIMAL(18,2))     AS Avg_Revenue_Per_Customer,
    CAST(100.0 * SUM(r.Total_Revenue) / SUM(SUM(r.Total_Revenue)) OVER () AS DECIMAL(6,2)) AS Pct_Of_Total_Revenue
FROM Customer_Revenue AS r
LEFT JOIN dbo.vw_crm_customers AS c
    ON c.msisdn = r.msisdn
GROUP BY COALESCE(UPPER(TRIM(c.mobile_type)), 'UNKNOWN')
ORDER BY Total_Revenue DESC;
-- 'UNKNOWN' includes revenue customers that are not in the CRM table.


-- 5.2 Revenue by system status
-- Business question: Do Active customers generate most of the revenue?
WITH Customer_Revenue AS (
    SELECT msisdn, SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
    GROUP BY msisdn
)
SELECT
    COALESCE(UPPER(TRIM(c.system_status)), 'UNKNOWN') AS System_Status,
    COUNT_BIG(*)                                      AS Customers,
    SUM(r.Total_Revenue)                              AS Total_Revenue,
    CAST(AVG(r.Total_Revenue) AS DECIMAL(18,2))       AS Avg_Revenue_Per_Customer
FROM Customer_Revenue AS r
LEFT JOIN dbo.vw_crm_customers AS c
    ON c.msisdn = r.msisdn
GROUP BY COALESCE(UPPER(TRIM(c.system_status)), 'UNKNOWN')
ORDER BY Total_Revenue DESC;