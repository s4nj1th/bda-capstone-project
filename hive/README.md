# Member 3 — Apache Hive Execution & Reproduction Guide

This directory contains the HiveQL DDL scripts and analytical queries for **Member 3: Apache Hive Data Warehousing & Analytics**.

---

## 1. Overview & Data Pipeline Demo Architecture

```
[Local CSV: data/processed/orders_clean.csv]
                   │
                   ▼ (hdfs dfs -put)
[HDFS Directory: /user/bda/food_delivery/clean/]
                   │
                   ▼ (OpenCSVSerde)
[Hive Staging External Table: orders_raw_text]
                   │
                   ▼ (CTAS with CAST & ORC format)
[Hive Managed Table: orders (ORC Columnar Format)]
                   │
                   ▼ (Hive CLI / HiveQL)
[12 Analytical Queries → results/hive_output/all_queries.txt]
```

---

## 2. Reproduction Instructions

### Step 1: Start Docker Services

Ensure Docker Desktop is running and start the Hadoop/Hive stack:

```bash
docker compose up -d
```

Verify that all services (`namenode`, `datanode`, `resourcemanager`, `nodemanager`, `hive-server`) are running:

```bash
docker compose ps
```

### Step 2: Upload Cleaned Dataset to HDFS

Create the target HDFS directory and upload `orders_clean.csv`:

```bash
# Create directory in HDFS
docker exec -it namenode hdfs dfs -mkdir -p /user/bda/food_delivery/clean/

# Copy cleaned dataset into NameNode container and upload to HDFS
docker cp data/processed/orders_clean.csv namenode:/tmp/orders_clean.csv
docker exec -it namenode hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/

# Verify file presence in HDFS
docker exec -it namenode hdfs dfs -ls /user/bda/food_delivery/clean/
```

### Step 3: Run Hive Setup and Queries (All-in-One)

Copy `hive/setup_and_run_hive.sql` into the `hive-server` container and execute it directly via the Hive CLI:

```bash
# 1. Copy the SQL file into the container
docker cp hive/setup_and_run_hive.sql hive-server:/tmp/setup_and_run_hive.sql

# 2. Execute the script in Hive
docker exec -it hive-server hive -f /tmp/setup_and_run_hive.sql
```

### Step 4: Save Query Results to Output File

To run the pipeline and save output to `results/hive_output/all_queries.txt`:

```bash
# Ensure results directory exists
mkdir -p results/hive_output

# Execute queries and redirect output
docker exec -i hive-server hive -f /tmp/setup_and_run_hive.sql > results/hive_output/all_queries.txt
```

---

## 3. Summary of the 12 Business Queries

| Query   | Business Question / Purpose                                                  | Key SQL Operations                       |
| ------- | ---------------------------------------------------------------------------- | ---------------------------------------- |
| **Q1**  | Total number of orders processed in the system                               | `COUNT(*)`                               |
| **Q2**  | Order volume breakdown across different restaurants                          | `GROUP BY`, `COUNT`, `ORDER BY`          |
| **Q3**  | Distribution of orders across statuses (Delivered, Cancelled, etc.)          | `GROUP BY`, `COUNT`                      |
| **Q4**  | Total gross revenue per restaurant for delivered orders                      | `WHERE`, `GROUP BY`, `SUM`, `ORDER BY`   |
| **Q5**  | Average order monetary value per restaurant                                  | `WHERE`, `GROUP BY`, `AVG`, `ROUND`      |
| **Q6**  | Top 10 highest value delivered orders                                        | `WHERE`, `ORDER BY`, `LIMIT`             |
| **Q7**  | Kitchen Preparation Time (KPT) metrics (Average, Max, Min) per restaurant    | `GROUP BY`, `AVG`, `MAX`, `MIN`, `WHERE` |
| **Q8**  | Delivery driver wait duration before order pickup per restaurant             | `GROUP BY`, `AVG`, `WHERE`               |
| **Q9**  | Order volume and spending behavior segmented by delivery distance            | `GROUP BY`, `COUNT`, `AVG`               |
| **Q10** | Customer satisfaction score (Average Rating) and review count per restaurant | `GROUP BY`, `AVG`, `COUNT`, `WHERE`      |
| **Q11** | Most frequent customer complaint categories                                  | `WHERE`, `GROUP BY`, `COUNT`, `ORDER BY` |
| **Q12** | High-performing restaurants (>500 orders and rating ≥ 4.0)                   | `GROUP BY`, `HAVING`, `AVG`, `COUNT`     |

---

## 4. Required-Operations Checklist

| Operation     | Covered in Query                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------- |
| **SELECT**    | All queries (Q1–Q12)                                                                              |
| **WHERE**     | Q4, Q5, Q6, Q7, Q8, Q10, Q11, Q12                                                                 |
| **ORDER BY**  | Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10, Q11, Q12                                                     |
| **GROUP BY**  | Q2, Q3, Q4, Q5, Q7, Q8, Q9, Q10, Q11, Q12                                                         |
| **HAVING**    | Q12                                                                                               |
| **COUNT**     | Q1, Q2, Q3, Q9, Q10, Q11, Q12                                                                     |
| **SUM**       | Q4                                                                                                |
| **AVG**       | Q5, Q7, Q8, Q9, Q10, Q12                                                                          |
| **MAX / MIN** | Q7                                                                                                |
| **JOIN**      | Single table dataset (`orders`); per capstone requirements, single-table analytics is sufficient. |

---

## 5. Viva Preparation Checklist

1. **External vs Managed Table Choice:**
    - `orders_raw_text` is **External**: Hive points directly to HDFS data (`/user/bda/food_delivery/clean/`). If `DROP TABLE` is executed, HDFS raw files remain intact.
    - `orders` is **Managed**: Hive owns both the metadata and data files. It optimizes data storage using ORC format.

2. **OpenCSVSerde vs Default Delimited SerDe:**
    - Free-text fields like `instructions` and `review` contain commas inside quoted strings (e.g. `"Good food, fast delivery"`).
    - Standard `,`-delimited text SerDe splits naively at every comma, shifting subsequent columns into wrong fields. `OpenCSVSerde` properly handles quotes and escapes.

3. **ORC Format & Strong Typing:**
    - Staging table reads everything as `STRING`.
    - Creating `orders` as an ORC table with explicit numeric casts (`DOUBLE`) optimizes query performance (column pruning, vectorization, compression) and ensures proper arithmetic aggregations.

4. **WHERE vs HAVING Difference (Example: Q4 vs Q12):**
    - `WHERE` filters individual rows **before** aggregation (e.g., Q4 filters `order_status = 'Delivered'`).
    - `HAVING` filters aggregated group results **after** `GROUP BY` calculation (e.g., Q12 filters groups where `COUNT(*) > 500 AND AVG(rating) >= 4.0`).

5. **Hive Architecture Under the Hood:**
    - HiveQL queries are parsed, type-checked, optimized into abstract syntax trees (AST) and logical execution plans, and translated into distributed MapReduce/Tez jobs executing across YARN cluster nodes.
