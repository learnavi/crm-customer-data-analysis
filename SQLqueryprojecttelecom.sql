/* ===============================================================
   CRM CUSTOMER ANALYSIS - SQL QUERIES
   Project : Telecom IoT Insights
   Database: SQL Server (T-SQL)
   Table   : CRM_Customers  (loaded from the cleaned crm1_clean.csv)

   Columns : msisdn (customer ID), gender, year_of_birth,
             system_status, mobile_type

   Contents:
     1. Customer overview
     2. System status & mobile type
     3. Gender analysis
     4. Age analysis
     5. Data quality checks
   ================================================================== */


/* ------------------------------------------------------------------
   1. CUSTOMER OVERVIEW
   ------------------------------------------------------------------ */

-- Preview the data
SELECT TOP 10 * FROM CRM_Customers;

-- Total records
SELECT COUNT(*) AS TotalRecords
FROM CRM_Customers;

-- Unique customers (msisdn = customer ID)
SELECT COUNT(DISTINCT msisdn) AS UniqueCustomers
FROM CRM_Customers;

-- Customers with more than one record
SELECT COUNT(*) AS CustomersWithMultipleRecords
FROM (
    SELECT msisdn
    FROM CRM_Customers
    GROUP BY msisdn
    HAVING COUNT(*) > 1
) AS t;

-- Customers with more than three records
SELECT COUNT(*) AS CustomersWithMoreThan3Records
FROM (
    SELECT msisdn
    FROM CRM_Customers
    GROUP BY msisdn
    HAVING COUNT(*) > 3
) AS t;

-- Customer with the highest number of records
SELECT TOP 1
    msisdn,
    COUNT(*) AS RecordCount
FROM CRM_Customers
GROUP BY msisdn
ORDER BY RecordCount DESC;

-- Customers whose records show more than one system status
SELECT COUNT(*) AS CustomersWithMultipleStatuses
FROM (
    SELECT msisdn
    FROM CRM_Customers
    GROUP BY msisdn
    HAVING COUNT(DISTINCT system_status) > 1
) AS t;

/* ------------------------------------------------------------------
   2. SYSTEM STATUS & MOBILE TYPE
   ------------------------------------------------------------------ */

-- Records and share (%) by system status
SELECT
    system_status,
    COUNT(*) AS RecordCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Percentage
FROM CRM_Customers
GROUP BY system_status
ORDER BY RecordCount DESC;

-- Overall suspension rate
SELECT
    CAST(
        SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS SuspensionRate
FROM CRM_Customers;

-- Records by mobile type and status
SELECT
    mobile_type,
    system_status,
    COUNT(*) AS RecordCount
FROM CRM_Customers
GROUP BY mobile_type, system_status
ORDER BY mobile_type, RecordCount DESC;

-- Active and suspension rate by mobile type
SELECT
    mobile_type,
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN system_status = 'ACTIVE'  THEN 1 ELSE 0 END) AS ActiveRecords,
    SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) AS SuspendedRecords,
    CAST(SUM(CASE WHEN system_status = 'ACTIVE'  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,2)) AS ActiveRate,
    CAST(SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,2)) AS SuspensionRate
FROM CRM_Customers
GROUP BY mobile_type
ORDER BY SuspensionRate DESC;

-- Where do most suspended records come from?
SELECT
    mobile_type,
    COUNT(*) AS SuspendedRecords
FROM CRM_Customers
WHERE system_status = 'SUSPEND'
GROUP BY mobile_type
ORDER BY SuspendedRecords DESC;

/* ------------------------------------------------------------------
   3. GENDER ANALYSIS
   ------------------------------------------------------------------ */

-- Records and share (%) by gender
SELECT
    gender,
    COUNT(*) AS RecordCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Percentage
FROM CRM_Customers
GROUP BY gender
ORDER BY RecordCount DESC;

-- Suspension rate by gender
SELECT
    gender,
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) AS SuspendedRecords,
    CAST(SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,2)) AS SuspensionRate
FROM CRM_Customers
GROUP BY gender
ORDER BY SuspensionRate DESC;

-- Gender vs mobile type
SELECT
    gender,
    mobile_type,
    COUNT(*) AS RecordCount
FROM CRM_Customers
GROUP BY gender, mobile_type
ORDER BY gender, RecordCount DESC;

-- Gender with the most suspended records
SELECT TOP 1
    gender,
    COUNT(*) AS SuspendedRecords
FROM CRM_Customers
WHERE system_status = 'SUSPEND'
GROUP BY gender
ORDER BY SuspendedRecords DESC;

/* ------------------------------------------------------------------
   4. AGE ANALYSIS
   ------------------------------------------------------------------ */

-- Average age (valid ages only, 18-100)
SELECT
    AVG(YEAR(GETDATE()) - year_of_birth * 1.0) AS AverageAge
FROM CRM_Customers
WHERE YEAR(GETDATE()) - year_of_birth BETWEEN 18 AND 100;

-- Age group distribution
WITH AgeData AS (
    SELECT
        CASE
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 18 AND 25 THEN '18-25'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 26 AND 35 THEN '26-35'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 36 AND 45 THEN '36-45'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 46 AND 55 THEN '46-55'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 56 AND 65 THEN '56-65'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 66 AND 100 THEN '66-100'
            ELSE 'Outside Range'
        END AS AgeGroup
    FROM CRM_Customers
)
SELECT
    AgeGroup,
    COUNT(*) AS RecordCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Percentage
FROM AgeData
GROUP BY AgeGroup
ORDER BY AgeGroup;

-- Suspension rate by age group
WITH AgeData AS (
    SELECT
        system_status,
        CASE
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 18 AND 25 THEN '18-25'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 26 AND 35 THEN '26-35'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 36 AND 45 THEN '36-45'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 46 AND 55 THEN '46-55'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 56 AND 65 THEN '56-65'
            WHEN YEAR(GETDATE()) - year_of_birth BETWEEN 66 AND 100 THEN '66-100'
        END AS AgeGroup
    FROM CRM_Customers
)
SELECT
    AgeGroup,
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) AS SuspendedRecords,
    CAST(SUM(CASE WHEN system_status = 'SUSPEND' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,2)) AS SuspensionRate
FROM AgeData
WHERE AgeGroup IS NOT NULL
GROUP BY AgeGroup
ORDER BY AgeGroup;

/* ------------------------------------------------------------------
   5. DATA QUALITY CHECKS
   ------------------------------------------------------------------ */

-- Missing birth years
SELECT COUNT(*) AS MissingBirthYears
FROM CRM_Customers
WHERE year_of_birth IS NULL;

-- Records with unknown gender
SELECT COUNT(*) AS UnknownGenderRecords
FROM CRM_Customers
WHERE gender = 'UNKNOWN';

-- Exact duplicate rows (expect no rows)
SELECT
    msisdn, gender, year_of_birth, system_status, mobile_type,
    COUNT(*) AS DuplicateCount
FROM CRM_Customers
GROUP BY msisdn, gender, year_of_birth, system_status, mobile_type
HAVING COUNT(*) > 1;

-- Unexpected system_status values (expect no rows)
SELECT DISTINCT system_status
FROM CRM_Customers
WHERE system_status NOT IN ('ACTIVE', 'SUSPEND', 'IDLE', 'DEACTIVE');

-- Unexpected mobile_type values (expect no rows)
SELECT DISTINCT mobile_type
FROM CRM_Customers
WHERE mobile_type NOT IN ('Prepaid', 'Postpaid');