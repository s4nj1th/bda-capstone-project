# Apache Hive Pipeline — Step-by-Step Execution Guide

This guide provides the exact terminal commands to run the Apache Hive portion of the pipeline end-to-end using the direct Hive CLI.

---

## Prerequisites

- Docker and Docker Compose installed and running.
- Cleaned dataset generated at `data/processed/orders_clean.csv`.

---

## Step 1: Start Docker Services

Start the Hadoop cluster and Hive services:

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
docker exec -i namenode hdfs dfs -mkdir -p /user/bda/food_delivery/clean/

# 2. Copy dataset to NameNode container and upload to HDFS
docker cp data/processed/orders_clean.csv namenode:/tmp/orders_clean.csv
docker exec -i namenode hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/

# 3. Verify file presence in HDFS
docker exec -i namenode hdfs dfs -ls /user/bda/food_delivery/clean/
```

---

## Step 3: Run Hive Setup and Queries (All-in-One)

Execute the complete end-to-end Hive pipeline (database creation, staging table, managed ORC table, and all 12 analytical queries):

```bash
# 1. Copy the SQL file into the container
docker cp hive/setup_and_run_hive.sql hive-server:/tmp/setup_and_run_hive.sql

# 2. Execute the script in Hive (displays results in terminal)
docker exec -it hive-server hive -f /tmp/setup_and_run_hive.sql
```

### Save Output to Results File

To save the complete query output to `results/hive_output/all_queries.txt`:

```bash
mkdir -p results/hive_output
docker exec -i hive-server hive -f /tmp/setup_and_run_hive.sql > results/hive_output/all_queries.txt
```

---

## Step 4: (Alternative) Run Setup and Queries Separately

If you prefer to run table creation and queries as separate steps:

```bash
# Table creation (Staging + ORC tables)
docker cp hive/setup.sql hive-server:/tmp/setup.sql
docker exec -it hive-server hive -f /tmp/setup.sql

# Analytical Queries (Q1–Q12)
docker cp hive/queries.sql hive-server:/tmp/queries.sql
docker exec -it hive-server hive -f /tmp/queries.sql
```

---

## Step 5: (Optional) Interactive Hive Shell

To explore or run ad-hoc HiveQL queries interactively:

```bash
docker exec -it hive-server hive
```

Inside the Hive shell:
```sql
USE food_delivery;
SHOW TABLES;
SELECT COUNT(*) FROM orders;
```

