-- 1. Creating Table & Import Data --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
create table SALES_DATASET_RFM_PRJ
(
  ordernumber VARCHAR,
  quantityordered  VARCHAR,
  priceeach        VARCHAR,
  orderlinenumber  VARCHAR,
  sales            VARCHAR,
  orderdate        VARCHAR,
  status           VARCHAR,
  productline      VARCHAR,
  msrp             VARCHAR,
  productcode      VARCHAR,
  customername     VARCHAR,
  phone            VARCHAR,
  addressline1     VARCHAR,
  addressline2     VARCHAR,
  city             VARCHAR,
  state            VARCHAR,
  postalcode       VARCHAR,
  country          VARCHAR,
  territory        VARCHAR,
  contactfullname  VARCHAR,
  dealsize         VARCHAR
) 

ALTER TABLE SALES_DATASET_RFM_PRJ
	ALTER COLUMN ordernumber TYPE INT USING(ordernumber::integer),
	ALTER COLUMN quantityordered TYPE SMALLINT USING(quantityordered::smallint),
	ALTER COLUMN priceeach TYPE DECIMAL USING(priceeach::decimal),
	ALTER COLUMN orderlinenumber TYPE SMALLINT USING(orderlinenumber::smallint),
	ALTER COLUMN sales TYPE DECIMAL USING(sales::decimal),
	ALTER COLUMN msrp TYPE SMALLINT USING(msrp::smallint),
  ALTER COLUMN contactfullname TYPE TEXT


/* Creating Table for the segmentation R-F-M Scores */
-- CREATE temporary table
CREATE TEMP TABLE score
(
segment VARCHAR,
scores VARCHAR	
)
-- insert values
INSERT INTO score
VALUES
('Potential Loyalist', '323, 333, 341, 342, 351, 352, 353, 423, 431, 432, 433, 441, 442, 451, 452, 453, 531, 532, 533, 541, 542, 551, 552, 553'),
('Cannot Lose Them', '113, 114, 115, 144, 154, 155, 214, 215'),
('Need Attention', '324, 325, 334, 343, 434, 443, 534, 535'),
('Hibernating customers', '122, 123, 132, 211, 212, 222, 223, 231, 232, 233, 241, 251, 322, 332'),
('About To Sleep', '213, 221, 231, 241, 251, 312, 321, 331'),
('Champions', '445, 454, 455, 544, 545, 554, 555'),
('Promising', '313, 314, 315, 413, 414, 415, 424, 425, 513, 514, 515, 521, 522, 523, 524, 525'),
('New Customers', '311, 411, 412, 421, 422, 511, 512'),
('At Risk', '124, 125, 133, 134, 135, 142, 143, 145, 152, 153, 224, 225, 234, 235, 242, 243, 244, 245, 252, 253, 254, 255'),
('Loyal', '335, 344, 345, 354, 355, 435, 444, 543'),
('Lost customers', '111, 112, 121, 131, 141, 151')
-- divide the each R-F-M Scores into a row and create a table for the result
CREATE TABLE segment_score
AS(
SELECT segment, REGEXP_SPLIT_TO_TABLE(scores, ', ')
FROM score
)
	
-- 2. Data Cleaning -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- NULL values
SELECT * FROM SALES_DATASET_RFM_PRJ
WHERE	ordernumber IS NULL
	OR quantityordered IS NULL
	OR priceeach IS NULL
	OR orderlinenumber IS NULL
	OR sales IS NULL
	OR orderdate IS NULL

-- Duplicate values


-- Outlier: Using Box-Plot method
WITH B1 AS (
SELECT	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY quantityordered) AS Q1,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantityordered) AS Q3,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantityordered)
		- PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY quantityordered) AS IQR
FROM SALES_DATASET_RFM_PRJ
)

, B2 AS (
SELECT	(Q1-1.5*IQR) AS min,
		(Q3+1.5*IQR) AS max
FROM B1
)

DELETE FROM SALES_DATASET_RFM_PRJ
WHERE 	quantityordered < (SELECT min FROM B2)
		OR quantityordered > (SELECT max FROM B2)

CREATE TABLE sales_dataset_rfm_prj_clean
AS( SELECT * FROM SALES_DATASET_RFM_PRJ )

-- 3. R-F-M Analysis ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Step1: Calculate R, F, M points
WITH B_1 AS (
SELECT	customername,
		current_date - MAX(orderdate) as R,
		COUNT(ordernumber) as F,
		SUM(sales) as M
FROM public.sales_dataset_rfm_prj_clean
GROUP BY customername
)
-- Step2: divide R, F, M points into 5 levels
, B_2 AS (
SELECT	customername,
		NTILE(5) OVER(ORDER BY R DESC) as R,
		NTILE(5) OVER(ORDER BY F) as F,
		NTILE(5) OVER(ORDER BY M) as M
FROM B_1
)
-- Step3: CONCAT(R,F,M)
, B_3 AS (
SELECT 	customername,
		CONCAT(r,f,m) as RFM
FROM B_2
)
-- Step4: Segmentation
SELECT	a.customername, a.rfm, b.segment
FROM B_3 as a
INNER JOIN segment_score as b
	ON a.rfm = b.scores
