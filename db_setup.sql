DROP DATABASE IF EXISTS gold_tracker;
CREATE DATABASE gold_tracker;
USE gold_tracker;

CREATE TABLE gold_price (
    id INT AUTO_INCREMENT PRIMARY KEY,
    price DECIMAL(10,2) NOT NULL,
    collected_date DATE NOT NULL UNIQUE,
    collected_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_date (collected_date)
);

CREATE TABLE price_statistics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    stat_date DATE NOT NULL UNIQUE,
    daily_avg DECIMAL(10,2),
    daily_min DECIMAL(10,2),
    daily_max DECIMAL(10,2),
    weekly_avg DECIMAL(10,2),
    monthly_avg DECIMAL(10,2),
    price_change DECIMAL(10,2),
    percent_change DECIMAL(5,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE collection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    collection_date DATE NOT NULL,
    collection_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    error_message TEXT,
    price_collected DECIMAL(10,2)
);

CREATE VIEW recent_prices AS
SELECT 
    id,
    price,
    collected_date,
    collected_time,
    ROUND(price - LAG(price) OVER (ORDER BY collected_date), 2) AS price_change,
    ROUND(((price - LAG(price) OVER (ORDER BY collected_date)) / LAG(price) OVER (ORDER BY collected_date)) * 100, 2) AS percent_change
FROM gold_price
WHERE collected_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY collected_date DESC;

CREATE VIEW price_summary AS
SELECT 
    COUNT(*) AS total_records,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(STDDEV(price), 2) AS std_deviation,
    MIN(collected_date) AS first_date,
    MAX(collected_date) AS last_date
FROM gold_price;

INSERT INTO gold_price (price, collected_date, collected_time) VALUES
(1923.50, '2025-10-01', '2025-10-01 12:00:00'),
(1926.80, '2025-10-02', '2025-10-02 12:00:00'),
(1930.10, '2025-10-03', '2025-10-03 12:00:00'),
(1928.40, '2025-10-04', '2025-10-04 12:00:00'),
(1932.00, '2025-10-05', '2025-10-05 12:00:00');

SELECT 'Database setup complete' AS Status;
