SELECT
    (SELECT COUNT(DISTINCT msisdn)
     FROM dbo.crm1_clean) AS CRM_Customers,

    (SELECT COUNT(DISTINCT msisdn)
     FROM dbo.rev1_clean) AS Revenue_Customers,

    (SELECT COUNT(DISTINCT msisdn)
     FROM dbo.device1_clean) AS Device_Customers;

     --Query 2 — Calculate total revenue per customer
     WITH Revenue_Summary AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
)
SELECT TOP 20
    c.msisdn,
    c.gender,
    c.mobile_type,
    c.system_status,
    r.Total_Revenue
FROM dbo.crm1_clean AS c
INNER JOIN Revenue_Summary AS r
    ON c.msisdn = r.msisdn
ORDER BY r.Total_Revenue DESC;

--Query 3 — Revenue by mobile type
WITH Revenue_Summary AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
),
Customer_Profile AS (
    SELECT
        msisdn,
        MAX(mobile_type) AS mobile_type
    FROM dbo.crm1_clean
    GROUP BY msisdn
)
SELECT
    c.mobile_type,
    COUNT(*) AS Customer_Count,
    SUM(r.Total_Revenue) AS Total_Revenue,
    AVG(r.Total_Revenue) AS Average_Customer_Revenue
FROM Customer_Profile AS c
INNER JOIN Revenue_Summary AS r
    ON c.msisdn = r.msisdn
GROUP BY c.mobile_type
ORDER BY Total_Revenue DESC;

--Query 4 — Revenue by device brand
WITH Revenue_Summary AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
),
Device_Profile AS (
    SELECT
        msisdn,
        MAX(brand_name) AS brand_name
    FROM dbo.device1_clean
    GROUP BY msisdn
)
SELECT
    d.brand_name,
    COUNT(*) AS Customer_Count,
    SUM(r.Total_Revenue) AS Total_Revenue,
    AVG(r.Total_Revenue) AS Average_Customer_Revenue
FROM Device_Profile AS d
INNER JOIN Revenue_Summary AS r
    ON d.msisdn = r.msisdn
GROUP BY d.brand_name
ORDER BY Total_Revenue DESC;

--revenue by gender
WITH Revenue_Summary AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
),
Customer_Profile AS (
    SELECT
        msisdn,
        MAX(gender) AS gender
    FROM dbo.crm1_clean
    GROUP BY msisdn
)
SELECT
    c.gender,
    COUNT(*) AS Customer_Count,
    SUM(r.Total_Revenue) AS Total_Revenue,
    AVG(r.Total_Revenue) AS Avg_Revenue_Per_Customer
FROM Customer_Profile AS c
INNER JOIN Revenue_Summary AS r
    ON c.msisdn = r.msisdn
GROUP BY c.gender
ORDER BY Total_Revenue DESC;

--Weekly Revenue Trend
SELECT
    week_number,
    SUM(revenue_usd) AS Total_Revenue,
    COUNT(DISTINCT msisdn) AS Active_Customers,
    AVG(revenue_usd) AS Avg_Revenue_Per_Record
FROM dbo.rev1_clean
GROUP BY week_number
ORDER BY week_number;

--Customer Revenue Segmentation
WITH Customer_Revenue AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
)
SELECT
    CASE
        WHEN Total_Revenue >= 200 THEN 'High'
        WHEN Total_Revenue >= 100 THEN 'Medium'
        ELSE 'Low'
    END AS Revenue_Segment,
    COUNT(*) AS Customer_Count,
    SUM(Total_Revenue) AS Segment_Revenue,
    AVG(Total_Revenue) AS Avg_Revenue_Per_Customer
FROM Customer_Revenue
GROUP BY
    CASE
        WHEN Total_Revenue >= 200 THEN 'High'
        WHEN Total_Revenue >= 100 THEN 'Medium'
        ELSE 'Low'
    END
ORDER BY Segment_Revenue DESC;

 --Validate Multiple Device Brands
 WITH Customer_Brands AS (
    SELECT
        msisdn,
        COUNT(DISTINCT brand_name) AS Brand_Count
    FROM dbo.device1_clean
    WHERE brand_name IS NOT NULL
    GROUP BY msisdn
)
SELECT
    CASE
        WHEN Brand_Count = 1 THEN 'One Brand'
        WHEN Brand_Count > 1 THEN 'Multiple Brands'
    END AS Brand_Category,
    COUNT(*) AS Customer_Count
FROM Customer_Brands
GROUP BY
    CASE
        WHEN Brand_Count = 1 THEN 'One Brand'
        WHEN Brand_Count > 1 THEN 'Multiple Brands'
    END;

    --Customer Matching Across All Three Tables
    WITH CRM_Customers AS (
    SELECT DISTINCT msisdn
    FROM dbo.crm1_clean
    WHERE msisdn IS NOT NULL
),
Revenue_Customers AS (
    SELECT DISTINCT msisdn
    FROM dbo.rev1_clean
    WHERE msisdn IS NOT NULL
),
Device_Customers AS (
    SELECT DISTINCT msisdn
    FROM dbo.device1_clean
    WHERE msisdn IS NOT NULL
)
SELECT
    COUNT(*) AS Customers_In_All_Three_Tables
FROM CRM_Customers AS c
INNER JOIN Revenue_Customers AS r
    ON c.msisdn = r.msisdn
INNER JOIN Device_Customers AS d
    ON c.msisdn = d.msisdn;

  --  Customer Profile Summary
  WITH Revenue_Summary AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
),
Customer_Profile AS (
    SELECT
        msisdn,
        MAX(gender) AS gender,
        MAX(mobile_type) AS mobile_type,
        MAX(system_status) AS system_status
    FROM dbo.crm1_clean
    GROUP BY msisdn
)
SELECT
    c.gender,
    c.mobile_type,
    c.system_status,
    COUNT(*) AS Customer_Count,
    SUM(r.Total_Revenue) AS Total_Revenue,
    AVG(r.Total_Revenue) AS Avg_Revenue_Per_Customer
FROM Customer_Profile AS c
INNER JOIN Revenue_Summary AS r
    ON c.msisdn = r.msisdn
GROUP BY
    c.gender,
    c.mobile_type,
    c.system_status
ORDER BY Total_Revenue DESC;
 --Final Business Summary
 WITH Customer_Revenue AS (
    SELECT
        msisdn,
        SUM(revenue_usd) AS Total_Revenue
    FROM dbo.rev1_clean
    GROUP BY msisdn
)
SELECT
    COUNT(*) AS Revenue_Generating_Customers,
    SUM(Total_Revenue) AS Total_Revenue_USD,
    AVG(Total_Revenue) AS Avg_Revenue_Per_Customer,
    MIN(Total_Revenue) AS Lowest_Customer_Revenue,
    MAX(Total_Revenue) AS Highest_Customer_Revenue
FROM Customer_Revenue;