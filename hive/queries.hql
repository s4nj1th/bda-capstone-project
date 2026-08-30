USE food_delivery;

-- Q1: Total number of orders (COUNT)
SELECT COUNT(*) AS total_orders FROM orders;

-- Q2: Orders by restaurant (GROUP BY, COUNT, ORDER BY)
SELECT restaurant_name, COUNT(*) AS order_count
FROM orders
GROUP BY restaurant_name
ORDER BY order_count DESC;

-- Q3: Orders by status (GROUP BY, COUNT)
SELECT order_status, COUNT(*) AS cnt
FROM orders
GROUP BY order_status
ORDER BY cnt DESC;

-- Q4: Revenue by restaurant (GROUP BY, SUM, ORDER BY)
SELECT restaurant_name, SUM(total) AS total_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
ORDER BY total_revenue DESC;

-- Q5: Average order value by restaurant (GROUP BY, AVG)
SELECT restaurant_name, ROUND(AVG(total), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
ORDER BY avg_order_value DESC;

-- Q6: Highest-value orders (WHERE, ORDER BY, LIMIT)
SELECT order_id, restaurant_name, total
FROM orders
WHERE order_status = 'Delivered'
ORDER BY total DESC
LIMIT 10;

-- Q7: Average KPT by restaurant (GROUP BY, AVG, MAX, MIN)
SELECT restaurant_name,
       ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt,
       MAX(kpt_duration_minutes) AS max_kpt,
       MIN(kpt_duration_minutes) AS min_kpt
FROM orders
WHERE kpt_duration_minutes IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_kpt DESC;

-- Q8: Average rider wait time by restaurant (GROUP BY, AVG)
SELECT restaurant_name, ROUND(AVG(rider_wait_time_minutes), 2) AS avg_rider_wait
FROM orders
WHERE rider_wait_time_minutes IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_rider_wait DESC;

-- Q9: Distance-based order behaviour (GROUP BY, COUNT, AVG)
SELECT distance, COUNT(*) AS order_count, ROUND(AVG(total), 2) AS avg_order_value
FROM orders
GROUP BY distance
ORDER BY order_count DESC;

-- Q10: Average rating by restaurant (GROUP BY, AVG, WHERE)
SELECT restaurant_name, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS num_ratings
FROM orders
WHERE rating IS NOT NULL
GROUP BY restaurant_name
ORDER BY avg_rating DESC;

-- Q11: Most frequent complaint types (WHERE, GROUP BY, COUNT, ORDER BY)
SELECT customer_complaint_tag, COUNT(*) AS complaint_count
FROM orders
WHERE customer_complaint_tag IS NOT NULL AND customer_complaint_tag <> ''
GROUP BY customer_complaint_tag
ORDER BY complaint_count DESC;

-- Q12: High-performing restaurants (GROUP BY, HAVING, AVG, COUNT)
-- "High performing" = decent volume AND high rating AND reasonably fast kitchen
SELECT restaurant_name,
       COUNT(*) AS order_count,
       ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt
FROM orders
WHERE order_status = 'Delivered'
GROUP BY restaurant_name
HAVING COUNT(*) > 500 AND AVG(rating) >= 4.0
ORDER BY avg_rating DESC;
