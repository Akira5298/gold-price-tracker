-- ============================================================================
-- Database Setup Script for Gold Price Tracker
-- Description: Creates database, tables, and necessary indexes for storing
--              gold price data with optimal query performance
-- Author: Alex
-- Date: December 2025
-- ============================================================================

-- Drop database if exists (for clean setup)
DROP DATABASE IF EXISTS gold_tracker;

-- Create database with UTF-8 encoding
CREATE DATABASE gold_tracker
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE gold_tracker;

-- ============================================================================
-- Table: gold_price
-- Description: Stores daily gold price records with collection metadata
-- ============================================================================
CREATE TABLE gold_price (
    id INT AUTO_INCREMENT PRIMARY KEY,
    price DECIMAL(10,2) NOT NULL,
    collected_date DATE NOT NULL,
    collected_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_price_positive CHECK (price > 0),
    CONSTRAINT chk_price_range CHECK (price BETWEEN 500.00 AND 10000.00),
    
    -- Unique constraint to prevent duplicate dates
    UNIQUE KEY unique_date (collected_date),
    
    -- Index for date-based queries (for plotting and analysis)
    INDEX idx_collected_date (collected_date DESC),
    
    -- Index for time-based queries
    INDEX idx_collected_time (collected_time DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: price_statistics
-- Description: Stores calculated statistics for quick reporting
-- ============================================================================
CREATE TABLE price_statistics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    stat_date DATE NOT NULL,
    daily_avg DECIMAL(10,2),
    daily_min DECIMAL(10,2),
    daily_max DECIMAL(10,2),
    weekly_avg DECIMAL(10,2),
    monthly_avg DECIMAL(10,2),
    price_change DECIMAL(10,2),
    percent_change DECIMAL(5,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Unique constraint for stat date
    UNIQUE KEY unique_stat_date (stat_date),
    
    -- Index for date queries
    INDEX idx_stat_date (stat_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: collection_logs
-- Description: Tracks data collection attempts and errors
-- ============================================================================
CREATE TABLE collection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    collection_date DATE NOT NULL,
    collection_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    error_message TEXT,
    price_collected DECIMAL(10,2),
    
    -- Index for status queries
    INDEX idx_status (status),
    
    -- Index for date queries
    INDEX idx_collection_date (collection_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- View: recent_prices
-- Description: View for quickly accessing last 30 days of price data
-- ============================================================================
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

-- ============================================================================
-- View: price_summary
-- Description: Statistical summary of gold prices
-- ============================================================================
CREATE VIEW price_summary AS
SELECT 
    COUNT(*) AS total_records,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(STDDEV(price), 2) AS std_deviation,
    MIN(collected_date) AS first_date,
    MAX(collected_date) AS last_date,
    DATEDIFF(MAX(collected_date), MIN(collected_date)) AS days_tracked
FROM gold_price;

-- ============================================================================
-- Stored Procedure: calculate_statistics
-- Description: Calculates and updates price statistics
-- ============================================================================
DELIMITER //

CREATE PROCEDURE calculate_statistics()
BEGIN
    DECLARE today DATE;
    SET today = CURDATE();
    
    -- Insert or update today's statistics
    INSERT INTO price_statistics (
        stat_date,
        daily_avg,
        daily_min,
        daily_max,
        weekly_avg,
        monthly_avg,
        price_change,
        percent_change
    )
    SELECT 
        today,
        ROUND(AVG(CASE WHEN collected_date = today THEN price END), 2),
        ROUND(MIN(CASE WHEN collected_date = today THEN price END), 2),
        ROUND(MAX(CASE WHEN collected_date = today THEN price END), 2),
        ROUND(AVG(CASE WHEN collected_date >= DATE_SUB(today, INTERVAL 7 DAY) THEN price END), 2),
        ROUND(AVG(CASE WHEN collected_date >= DATE_SUB(today, INTERVAL 30 DAY) THEN price END), 2),
        ROUND(MAX(CASE WHEN collected_date = today THEN price END) - MAX(CASE WHEN collected_date = DATE_SUB(today, INTERVAL 1 DAY) THEN price END), 2),
        ROUND((MAX(CASE WHEN collected_date = today THEN price END) - MAX(CASE WHEN collected_date = DATE_SUB(today, INTERVAL 1 DAY) THEN price END)) / MAX(CASE WHEN collected_date = DATE_SUB(today, INTERVAL 1 DAY) THEN price END) * 100, 2)
    FROM gold_price
    ON DUPLICATE KEY UPDATE
        daily_avg = VALUES(daily_avg),
        daily_min = VALUES(daily_min),
        daily_max = VALUES(daily_max),
        weekly_avg = VALUES(weekly_avg),
        monthly_avg = VALUES(monthly_avg),
        price_change = VALUES(price_change),
        percent_change = VALUES(percent_change);
END//

DELIMITER ;

-- ============================================================================
-- Insert Sample Data (for testing purposes)
-- ============================================================================
INSERT INTO gold_price (price, collected_date, collected_time) VALUES
(1923.50, '2025-10-01', '2025-10-01 12:00:00'),
(1926.80, '2025-10-02', '2025-10-02 12:00:00'),
(1930.10, '2025-10-03', '2025-10-03 12:00:00'),
(1928.40, '2025-10-04', '2025-10-04 12:00:00'),
(1932.00, '2025-10-05', '2025-10-05 12:00:00');

-- ============================================================================
-- Display Setup Information
-- ============================================================================
SELECT 'Database setup completed successfully!' AS Status;
SELECT * FROM price_summary;
