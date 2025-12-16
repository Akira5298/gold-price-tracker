CREATE DATABASE gold_tracker;
USE gold_tracker;

CREATE TABLE gold_price (
    id INT AUTO_INCREMENT PRIMARY KEY,
    price DECIMAL(10,2),
    collected_date DATE
);
