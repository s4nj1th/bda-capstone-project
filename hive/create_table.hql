CREATE DATABASE IF NOT EXISTS food_delivery;
USE food_delivery;

DROP TABLE IF EXISTS orders_raw_text;

-- Staging table: reads the CSV as-is (all STRING) using a CSV-aware SerDe
-- so quoted commas inside review/instructions text don't break parsing.
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

-- Cleaned/typed table used for all analytical queries.
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
