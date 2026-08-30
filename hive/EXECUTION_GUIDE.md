# Apache Hive Pipeline — Step-by-Step Execution Guide

This guide provides the exact terminal commands to run the Apache Hive portion of the pipeline end-to-end.

---

## Prerequisites

- Docker and Docker Compose installed and running.
- Cleaned dataset generated at `data/processed/orders_clean.csv`.

---

## Step 1: Start Docker Services

Start the Hadoop cluster and HiveServer2:

```bash
docker compose up -d
```

Verify that all 5 services are active (`namenode`, `datanode`, `resourcemanager`, `nodemanager`, `hive-server`):

```bash
docker compose ps
```

---

## Step 2: Upload Cleaned Data to HDFS

Upload the preprocessed CSV dataset to the target HDFS directory:

```bash
# 1. Create HDFS directory
docker exec -i bda-capstone-project-namenode-1 hdfs dfs -mkdir -p /user/bda/food_delivery/clean/

# 2. Copy dataset to NameNode container and upload to HDFS
docker cp data/processed/orders_clean.csv bda-capstone-project-namenode-1:/tmp/orders_clean.csv
docker exec -i bda-capstone-project-namenode-1 hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/

# 3. Verify file presence in HDFS
docker exec -i bda-capstone-project-namenode-1 hdfs dfs -ls /user/bda/food_delivery/clean/
```

---

## Step 3: Create Hive Database and Tables

Run `hive/create_table.hql` using Beeline to create:
1. `food_delivery` database
2. `orders_raw_text` external staging table (using `OpenCSVSerde`)
3. `orders` managed ORC table with typed numeric columns

```bash
# Copy DDL script to hive-server container
docker cp hive/create_table.hql bda-capstone-project-hive-server-1:/tmp/create_table.hql

# Execute table creation via Beeline
docker exec -i bda-capstone-project-hive-server-1 beeline -u jdbc:hive2://localhost:10000 -f /tmp/create_table.hql
```

---

## Step 4: Run the 12 Analytical Business Queries

Execute `hive/queries.hql` and save the query results to `results/hive_output/all_queries.txt`:

```bash
# Ensure output directory exists
mkdir -p results/hive_output

# Copy query script to hive-server container
docker cp hive/queries.hql bda-capstone-project-hive-server-1:/tmp/queries.hql

# Execute queries and pipe output to file
docker exec -i bda-capstone-project-hive-server-1 beeline -u jdbc:hive2://localhost:10000 -f /tmp/queries.hql > results/hive_output/all_queries.txt
```

---

## Step 5: (Optional) Interactive Querying via Beeline

To explore or run ad-hoc HiveQL queries interactively:

```bash
docker exec -it bda-capstone-project-hive-server-1 beeline -u jdbc:hive2://localhost:10000
```

Inside the Beeline prompt:
```sql
USE food_delivery;
SHOW TABLES;
SELECT COUNT(*) FROM orders;
```
