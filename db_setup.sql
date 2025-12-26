--If the database already exists, it is deleted
--Then creates and selects a new database

DROP DATABASE IF EXISTS goldtracker;
CREATE DATABASE goldtracker;
USE goldtracker;

--First table: stores daily gold prices
--Prevents storing more than one gold price for the same date
--An index on the date helps make searches and reports faster

CREATE TABLE goldprice (
    id INT AUTO_INCREMENT PRIMARY KEY,
    price DECIMAL(10,2) NOT NULL,
    collecteddate DATE NOT NULL UNIQUE,
    collectedtime DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_date (collecteddate)
);

--Second table: stores calculated statistics for each day
--It stores summaries on a daily, weekly, and monthly basis
--Without the need of recalculating them every time

CREATE TABLE pricestatistics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    statdate DATE NOT NULL UNIQUE,
    dailyavg DECIMAL(10,2),
    dailymin DECIMAL(10,2),
    dailymax DECIMAL(10,2),
    weeklyavg DECIMAL(10,2),
    monthlyavg DECIMAL(10,2),
    pricechange DECIMAL(10,2),
    percentchange DECIMAL(5,2),
    updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

--Third table: tracks every data collection attempt
--It records the success or failure of the collection
--And stores error messages in case something went wrong

CREATE TABLE collectionlogs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    collectiondate DATE NOT NULL,
    collectiontime DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    errormessage TEXT,
    pricecollected DECIMAL(10,2)
);

--'VIEW' = behaves like a virtual table that display the most recent data
--First VIEW shows prices from the last 30 days
--Also calculates day-to-day price changes and percentages
--Second VIEW provides a quick summary of the whole dataset

CREATE VIEW recentprices AS
SELECT 
    id,
    price,
    collecteddate,
    collectedtime,
    ROUND(price - LAG(price) OVER (ORDER BY collecteddate), 2) AS pricechange,
    ROUND(((price - LAG(price) OVER (ORDER BY collecteddate)) / LAG(price) OVER (ORDER BY collecteddate)) * 100, 2) AS percentchange
FROM goldprice
WHERE collecteddate >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY collecteddate DESC;

CREATE VIEW pricesummary AS
SELECT 
    COUNT(*) AS totalrecords,
    MIN(price) AS minprice,
    MAX(price) AS maxprice,
    ROUND(AVG(price), 2) AS avgprice,
    ROUND(STDDEV(price), 2) AS stddeviation,
    MIN(collecteddate) AS firstdate,
    MAX(collecteddate) AS lastdate
FROM goldprice;

--Inserts example gold price data
--Last part confirms that the database setup finished successfully

INSERT INTO goldprice (price, collecteddate, collectedtime) VALUES
(2045.30, '2025-11-01', '2025-11-01 12:00:00'),
(2048.75, '2025-11-02', '2025-11-02 12:00:00'),
(2052.10, '2025-11-03', '2025-11-03 12:00:00'),
(2049.85, '2025-11-04', '2025-11-04 12:00:00'),
(2055.40, '2025-11-05', '2025-11-05 12:00:00'),
(2058.90, '2025-11-06', '2025-11-06 12:00:00'),
(2062.25, '2025-11-07', '2025-11-07 12:00:00'),
(2059.60, '2025-11-08', '2025-11-08 12:00:00'),
(2063.45, '2025-11-09', '2025-11-09 12:00:00'),
(2067.80, '2025-11-10', '2025-11-10 12:00:00'),
(2065.15, '2025-11-11', '2025-11-11 12:00:00'),
(2070.50, '2025-11-12', '2025-11-12 12:00:00'),
(2068.20, '2025-11-13', '2025-11-13 12:00:00'),
(2072.85, '2025-11-14', '2025-11-14 12:00:00'),
(2069.40, '2025-11-15', '2025-11-15 12:00:00'),
(2074.95, '2025-11-16', '2025-11-16 12:00:00'),
(2071.30, '2025-11-17', '2025-11-17 12:00:00'),
(2076.60, '2025-11-18', '2025-11-18 12:00:00'),
(2080.15, '2025-11-19', '2025-11-19 12:00:00'),
(2077.85, '2025-11-20', '2025-11-20 12:00:00'),
(2083.40, '2025-11-21', '2025-11-21 12:00:00'),
(2086.70, '2025-11-22', '2025-11-22 12:00:00'),
(2084.20, '2025-11-23', '2025-11-23 12:00:00'),
(2089.55, '2025-11-24', '2025-11-24 12:00:00'),
(2092.90, '2025-11-25', '2025-11-25 12:00:00'),
(2090.35, '2025-11-26', '2025-11-26 12:00:00'),
(2095.80, '2025-11-27', '2025-11-27 12:00:00'),
(2093.15, '2025-11-28', '2025-11-28 12:00:00'),
(2098.60, '2025-11-29', '2025-11-29 12:00:00'),
(2096.25, '2025-11-30', '2025-11-30 12:00:00'),
(2101.50, '2025-12-01', '2025-12-01 12:00:00'),
(2099.80, '2025-12-02', '2025-12-02 12:00:00'),
(2104.35, '2025-12-03', '2025-12-03 12:00:00'),
(2107.90, '2025-12-04', '2025-12-04 12:00:00'),
(2105.20, '2025-12-05', '2025-12-05 12:00:00'),
(2110.65, '2025-12-06', '2025-12-06 12:00:00'),
(2108.40, '2025-12-07', '2025-12-07 12:00:00'),
(2113.75, '2025-12-08', '2025-12-08 12:00:00'),
(2111.10, '2025-12-09', '2025-12-09 12:00:00'),
(2116.55, '2025-12-10', '2025-12-10 12:00:00'),
(2114.90, '2025-12-11', '2025-12-11 12:00:00'),
(2119.30, '2025-12-12', '2025-12-12 12:00:00'),
(2117.65, '2025-12-13', '2025-12-13 12:00:00'),
(2122.40, '2025-12-14', '2025-12-14 12:00:00'),
(2120.85, '2025-12-15', '2025-12-15 12:00:00'),
(2125.20, '2025-12-16', '2025-12-16 12:00:00'),
(2123.50, '2025-12-17', '2025-12-17 12:00:00'),
(2128.95, '2025-12-18', '2025-12-18 12:00:00'),
(2126.30, '2025-12-19', '2025-12-19 12:00:00'),
(2131.70, '2025-12-20', '2025-12-20 12:00:00'),
(2129.15, '2025-12-21', '2025-12-21 12:00:00'),
(2134.60, '2025-12-22', '2025-12-22 12:00:00'),
(2132.45, '2025-12-23', '2025-12-23 12:00:00');

SELECT 'Database setup complete' AS Status;
