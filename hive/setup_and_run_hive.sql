-- ============================================================================
-- End-to-End Hive Data Warehousing and Analytical Query Script
-- Database: food_delivery
-- Staging Table: orders_raw_text (External Table via OpenCSVSerde)
-- Managed Table: orders (Optimized Columnar ORC Table)
-- ============================================================================

-- Step 1: Database Setup
CREATE DATABASE IF NOT EXISTS food_delivery;
USE food_delivery;

-- Step 2: Create Staging External Table
DROP TABLE IF EXISTS orders_raw_text;

CREATE EXTERNAL TABLE orders_raw_text (
    restaurant_id              STRING,
    restaurant_name            STRING,
    subzone                    STRING,
    city                       STRING,
    order_id                   STRING,
    order_placed_at            STRING,
    order_status               STRING,
    delivery                   STRING,
    distance                   STRING,
    items_in_order             STRING,
    instructions               STRING,
    discount_construct         STRING,
    bill_subtotal              STRING,
    packaging_charges          STRING,
    restaurant_discount_promo  STRING,
    restaurant_discount_flat   STRING,
    gold_discount              STRING,
    brand_pack_discount        STRING,
    total                      STRING,
    rating                     STRING,
    review                     STRING,
    cancellation_reason        STRING,
    restaurant_compensation    STRING,
    restaurant_penalty         STRING,
    kpt_duration_minutes       STRING,
    rider_wait_time_minutes    STRING,
    order_ready_marked         STRING,
    customer_complaint_tag     STRING,
    customer_id                STRING,
    order_placed_at_raw        STRING,
    flag_negative_financial    STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   "separatorChar" = ",",
   "quoteChar"     = "\"",
   "escapeChar"    = "\\"
)
STORED AS TEXTFILE
LOCATION '/user/bda/food_delivery/clean/'
TBLPROPERTIES ("skip.header.line.count"="1");

-- Step 3: Create Managed Typed ORC Table
DROP TABLE IF EXISTS orders;

CREATE TABLE orders
STORED AS ORC
AS
SELECT
    restaurant_id,
    restaurant_name,
    subzone,
    city,
    order_id,
    order_placed_at,
    order_status,
    delivery,
    distance,
    items_in_order,
    instructions,
    discount_construct,
    CAST(bill_subtotal AS DOUBLE)             AS bill_subtotal,
    CAST(packaging_charges AS DOUBLE)         AS packaging_charges,
    CAST(restaurant_discount_promo AS DOUBLE)  AS restaurant_discount_promo,
    CAST(restaurant_discount_flat AS DOUBLE)   AS restaurant_discount_flat,
    CAST(gold_discount AS DOUBLE)              AS gold_discount,
    CAST(brand_pack_discount AS DOUBLE)        AS brand_pack_discount,
    CAST(total AS DOUBLE)                      AS total,
    CAST(rating AS DOUBLE)                     AS rating,
    review,
    cancellation_reason,
    CAST(restaurant_compensation AS DOUBLE)    AS restaurant_compensation,
    CAST(restaurant_penalty AS DOUBLE)         AS restaurant_penalty,
    CAST(kpt_duration_minutes AS DOUBLE)       AS kpt_duration_minutes,
    CAST(rider_wait_time_minutes AS DOUBLE)    AS rider_wait_time_minutes,
    order_ready_marked,
    customer_complaint_tag,
    customer_id,
    order_placed_at_raw,
    flag_negative_financial
FROM orders_raw_text;

-- ============================================================================
-- 12 Analytical Business Queries
-- ============================================================================

-- Q1: Total number of orders (COUNT)
SELECT '--- Q1: Total Orders ---' AS query_title;
SELECT COUNT(*) AS total_orders FROM orders;

-- Q2: Orders by restaurant (GROUP BY, COUNT, ORDER BY)
SELECT '--- Q2: Orders by Restaurant ---' AS query_title;
SELECT restaurant_name, COUNT(*) AS order_count
FROM orders
GROUP BY restaurant_name
ORDER BY order_count DESC;

-- Q3: Orders by status (GROUP BY, COUNT)
SELECT '--- Q3: Orders by Status ---' AS query_title;
SELECT order_status, COUNT(*) AS cnt
FROM orders
GROUP BY order_status
ORDER BY cnt DESC;

-- Q4: Revenue by restaurant for delivered orders (GROUP BY, SUM, ORDER BY)
SELECT '--- Q4: Revenue by Restaurant ---' AS query_title;
SELECT restaurant_name, SUM(total) AS total_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
ORDER BY total_revenue DESC;

-- Q5: Average order value by restaurant (GROUP BY, AVG)
SELECT '--- Q5: Average Order Value by Restaurant ---' AS query_title;
SELECT restaurant_name, ROUND(AVG(total), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
ORDER BY avg_order_value DESC;

-- Q6: Top 10 highest-value orders (WHERE, ORDER BY, LIMIT)
SELECT '--- Q6: Top 10 Highest-Value Orders ---' AS query_title;
SELECT order_id, restaurant_name, total
FROM orders
WHERE order_status = 'Delivered'
ORDER BY total DESC
LIMIT 10;

-- Q7: Average KPT by restaurant (GROUP BY, AVG, MAX, MIN)
SELECT '--- Q7: Kitchen Prep Time (KPT) by Restaurant ---' AS query_title;
SELECT restaurant_name,
       ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt,
       MAX(kpt_duration_minutes) AS max_kpt,
       MIN(kpt_duration_minutes) AS min_kpt
FROM orders
WHERE kpt_duration_minutes IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_kpt DESC;

-- Q8: Average rider wait time by restaurant (GROUP BY, AVG)
SELECT '--- Q8: Rider Wait Time by Restaurant ---' AS query_title;
SELECT restaurant_name, ROUND(AVG(rider_wait_time_minutes), 2) AS avg_rider_wait
FROM orders
WHERE rider_wait_time_minutes IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_rider_wait DESC;

-- Q9: Distance-based order behavior (GROUP BY, COUNT, AVG)
SELECT '--- Q9: Distance-based Order Behaviour ---' AS query_title;
SELECT distance, COUNT(*) AS order_count, ROUND(AVG(total), 2) AS avg_order_value
FROM orders
GROUP BY distance
ORDER BY order_count DESC;

-- Q10: Customer satisfaction (Average rating & review count) by restaurant (GROUP BY, AVG, WHERE)
SELECT '--- Q10: Customer Rating and Review Count by Restaurant ---' AS query_title;
SELECT restaurant_name, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS num_ratings
FROM orders
WHERE rating IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_rating DESC;

-- Q11: Most frequent customer complaints (WHERE, GROUP BY, COUNT, ORDER BY)
SELECT '--- Q11: Most Frequent Customer Complaints ---' AS query_title;
SELECT customer_complaint_tag, COUNT(*) AS complaint_count
FROM orders
WHERE customer_complaint_tag IS NOT NULL AND customer_complaint_tag <> ''
GROUP BY customer_complaint_tag
ORDER BY complaint_count DESC;

-- Q12: High-performing restaurants (GROUP BY, HAVING, AVG, COUNT)
SELECT '--- Q12: High-Performing Restaurants (Volume > 500 & Rating >= 4.0) ---' AS query_title;
SELECT restaurant_name,
       COUNT(*) AS order_count,
       ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
HAVING COUNT(*) > 500 AND AVG(rating) >= 4.0
ORDER BY avg_rating DESC;
