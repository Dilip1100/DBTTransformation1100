----------------------------------------PRE-REQUISITE--FILE-HANDLING----------------------------------------------------

SELECT DISTINCT METADATA$FILENAME AS FILENAME
FROM @RETAIL.DBTCORE.BRONZESTG

-------------------------------------------BRONZE-INJESTION-JSON--------------------------------------------------------
WITH BRZE AS (
    SELECT
        $1:ADDRESSLINE1::STRING AS ADDRESSLINE1, 
        $1:ADDRESSLINE2::STRING AS ADDRESSLINE2, 
        $1:CITY::STRING AS CITY, 
        $1:CONTACTFIRSTNAME::STRING AS CONTACTFIRSTNAME, 
        $1:CONTACTLASTNAME::STRING AS CONTACTLASTNAME, 
        $1:COUNTRY::STRING AS COUNTRY, 
        $1:CUSTOMERNAME::STRING AS CUSTOMERNAME, 
        $1:DEALSIZE::STRING AS DEALSIZE, 
        $1:MONTH_ID::STRING AS MONTH_ID, 
        $1:MSRP::STRING AS MSRP, 
        $1:ORDERDATE::STRING AS ORDERDATE, 
        $1:ORDERLINENUMBER::STRING AS ORDERLINENUMBER, 
        $1:ORDERNUMBER::STRING AS ORDERNUMBER, 
        $1:PHONE::STRING AS PHONE, 
        $1:POSTALCODE::STRING AS POSTALCODE, 
        $1:PRICEEACH::STRING AS PRICEEACH, 
        $1:PRODUCTCODE::STRING AS PRODUCTCODE, 
        $1:PRODUCTLINE::STRING AS PRODUCTLINE, 
        $1:QTR_ID::STRING AS QTR_ID, 
        $1:QUANTITYORDERED::STRING AS QUANTITYORDERED, 
        $1:SALES::STRING AS SALES, 
        $1:STATE::STRING AS STATE, 
        $1:STATUS::STRING AS STATUS, 
        $1:TERRITORY::STRING AS TERRITORY, 
        $1:YEAR_ID::STRING AS YEAR_ID,
        CURRENT_TIMESTAMP AS UPDATEDAT
    FROM @RETAIL.DBTCORE.BRONZESTG(FILE_FORMAT => RETAIL.DBTCORE.JAB1100)
    WHERE METADATA$FILENAME IN (SELECT * FROM PROCESSED)
)
SELECT * FROM BRZE
------------------------------------------SYNTHETIC-ATTRIBUTE-CREATION--------------------------------------------------
WITH SRC AS (
  SELECT
    *,
    ROUND(SALES * (1 - CASE 
        WHEN COUNTRY = 'France' THEN 0.10
        WHEN COUNTRY = 'Spain' THEN 0.14
        WHEN COUNTRY = 'Australia' THEN 0.10
        WHEN COUNTRY = 'Philippines' THEN 0.08
        WHEN COUNTRY = 'Norway' THEN 0.08
        WHEN COUNTRY = 'USA' THEN 0.20
        WHEN COUNTRY = 'Sweden' THEN 0.30
        WHEN COUNTRY = 'Belgium' THEN 0.25
        WHEN COUNTRY = 'Switzerland' THEN 0.30
        WHEN COUNTRY = 'Austria' THEN 0.15
        WHEN COUNTRY = 'Finland' THEN 0.12
        WHEN COUNTRY = 'Singapore' THEN 0.24
        WHEN COUNTRY = 'Germany' THEN 0.47
        WHEN COUNTRY = 'UK' THEN 0.40
        WHEN COUNTRY = 'Denmark' THEN 0.18
        WHEN COUNTRY = 'Japan' THEN 0.20
        WHEN COUNTRY = 'Canada' THEN 0.27
        WHEN COUNTRY = 'Italy' THEN 0.10
        WHEN COUNTRY = 'Ireland' THEN 0.26
        ELSE 0
    END), 2) AS REVENUE,
    ROUND(SALES * CASE 
        WHEN COUNTRY = 'France' THEN 0.10
        WHEN COUNTRY = 'Spain' THEN 0.14
        WHEN COUNTRY = 'Australia' THEN 0.10
        WHEN COUNTRY = 'Philippines' THEN 0.08
        WHEN COUNTRY = 'Norway' THEN 0.08
        WHEN COUNTRY = 'USA' THEN 0.20
        WHEN COUNTRY = 'Sweden' THEN 0.30
        WHEN COUNTRY = 'Belgium' THEN 0.25
        WHEN COUNTRY = 'Switzerland' THEN 0.30
        WHEN COUNTRY = 'Austria' THEN 0.15
        WHEN COUNTRY = 'Finland' THEN 0.12
        WHEN COUNTRY = 'Singapore' THEN 0.24
        WHEN COUNTRY = 'Germany' THEN 0.47
        WHEN COUNTRY = 'UK' THEN 0.40
        WHEN COUNTRY = 'Denmark' THEN 0.18
        WHEN COUNTRY = 'Japan' THEN 0.20
        WHEN COUNTRY = 'Canada' THEN 0.27
        WHEN COUNTRY = 'Italy' THEN 0.10
        WHEN COUNTRY = 'Ireland' THEN 0.26
        ELSE 0
    END, 2) AS DISCOUNT_AMOUNT
FROM 
    {{ ref('BRONZE') }}
)
SELECT * FROM SRC
-------------------------SILVER-STAGING-RELEVANT-ATTRIBUTES-AND FILTERING BASED ON SHIPPING-STSTUS----------------------

SELECT 
    ORDERNUMBER, 
    CUSTOMERNAME, 
    COUNTRY, 
    DISCOUNT_AMOUNT, 
    REVENUE, 
    YEAR_ID, 
    QTR_ID, 
    STATUS 
FROM 
    {{ ref('SYNTH') }} 
WHERE 
    STATUS = 'Resolved' 
    OR STATUS = 'Shipped'


-------------------------------------------------GOLD-STAGE-AGGREGATION-------------------------------------------------
SELECT 
    ORDERNUMBER, 
    CUSTOMERNAME, 
    COUNTRY,
    YEAR_ID,
    QTR_ID, 
    ROUND(REVENUES, 2) AS REVENUE,
    ROUND(LOSSS, 2) AS LOSS
FROM 
    (SELECT 
        ORDERNUMBER, 
        CUSTOMERNAME, 
        COUNTRY,
        YEAR_ID,
        QTR_ID,
        SUM(REVENUE) AS REVENUES,
        SUM(DISCOUNT_AMOUNT) AS LOSSS
    FROM 
        {{ ref('SILVER') }}
    WHERE 
        DISCOUNT_AMOUNT > 0 
    GROUP BY 
        YEAR_ID,
        QTR_ID,
        ORDERNUMBER,
        CUSTOMERNAME, 
        COUNTRY
    ) AS SB
-------------------------------------PLATINUM-STAGE-BI-READY-SCHEMATIC-DATA---------------------------------------------


SELECT CUSTOMERNAME, COUNTRY, YEAR_ID, QTR_ID, SUM(LOSS) AS TOTALLOSS, SUM(REVENUE) AS TOTALREVENUE, 
SUM(REVENUE) - SUM(LOSS) AS PROFIT FROM {{ref('GOLD')}} GROUP BY YEAR_ID, QTR_ID, CUSTOMERNAME, 
COUNTRY ORDER BY YEAR_ID DESC, QTR_ID DESC
