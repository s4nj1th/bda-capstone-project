# Big Data Analytics Capstone Project — Food Delivery Analytics

This repository contains the end-to-end Big Data pipeline for analyzing large-scale food delivery order data using **Hadoop (HDFS & YARN)**, **MapReduce**, and **Apache Hive**.

---

## Architecture & Docker Services

The cluster is orchestrated using Docker Compose (`docker-compose.yml`):

| Container Name    | Service              | Function                                            | Web UI / Ports           |
| :---------------- | :------------------- | :-------------------------------------------------- | :----------------------- |
| `namenode`        | HDFS NameNode        | Master node managing HDFS metadata & directory tree | `http://localhost:9870`  |
| `datanode`        | HDFS DataNode        | Worker node storing distributed data blocks         | —                        |
| `resourcemanager` | YARN ResourceManager | Cluster resource manager & job scheduler            | `http://localhost:8088`  |
| `nodemanager`     | YARN NodeManager     | Worker node launching distributed compute tasks     | —                        |
| `hive-server`     | Apache Hive          | Hive CLI & HiveServer2 execution engine             | `http://localhost:10002` |

---

## ⚙️ Prerequisites & Mac / Apple Silicon Setup

If running on Apple Silicon (M1 / M2 / M3 / M4 Macs):
1. In **Docker Desktop -> Settings -> Resources**:
   - Allocate at least **6 GB – 8 GB** of Memory.
   - Allocate at least **4 CPUs**.
2. In **Docker Desktop -> Settings -> General** (or Features in Development):
   - Check **"Use Rosetta for x86/amd64 emulation on Apple Silicon"** for optimal x86 container performance and stability.
3. Click **Apply & restart**.

---

## 🚀 Quickstart & Pipeline Execution

### Step 1: Start the Cluster

```bash
# Start cluster (use -v on first run if resetting volume state)
docker compose up -d
```

Verify all 5 services are active (`Up`):

```bash
docker compose ps
```

---

### Step 2: Initialize HDFS & Upload Cleaned Data

Create required HDFS directories, grant Hive scratch permissions, and upload `orders_clean.csv`:

```bash
# 1. Create HDFS directories & configure Hive permissions
docker exec -i namenode hdfs dfs -mkdir -p /tmp/hive /user/hive/warehouse /user/bda/food_delivery/clean/ /food_delivery/input/
docker exec -i namenode hdfs dfs -chmod -R 777 /tmp /user/hive/warehouse

# 2. Copy processed dataset to NameNode and upload to HDFS
docker cp data/processed/orders_clean.csv namenode:/tmp/orders_clean.csv
docker exec -i namenode hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/orders_clean.csv
docker exec -i namenode hdfs dfs -put -f /tmp/orders_clean.csv /food_delivery/input/orders_clean.csv

# 3. Verify HDFS files
docker exec -i namenode hdfs dfs -ls /user/bda/food_delivery/clean/
```

---

### Step 3: Run Apache Hive Analytics Pipeline

Execute the end-to-end Hive pipeline (database creation, staging table, managed ORC table, and 12 business queries):

```bash
# 1. Copy the SQL script into the container
docker cp hive/setup_and_run_hive.sql hive-server:/tmp/setup_and_run_hive.sql

# 2. Execute script via Hive CLI (outputs results directly to terminal)
docker exec -it hive-server hive -f /tmp/setup_and_run_hive.sql

# Or execute and redirect output to results file:
mkdir -p results/hive_output
docker exec -i hive-server hive -f /tmp/setup_and_run_hive.sql > results/hive_output/all_queries.txt
```

---

### Step 4: Verify Databases & Tables in Hive

#### Option A: Interactive Hive Shell
```bash
docker exec -it hive-server hive
```
Inside the `hive>` prompt:
```sql
SHOW DATABASES;
USE food_delivery;
SHOW TABLES;
DESCRIBE orders;
SELECT order_id, restaurant_name, total, rating, order_status FROM orders LIMIT 5;
SELECT COUNT(*) FROM orders;
EXIT;
```

#### Option B: One-Line CLI Commands
```bash
# Show databases
docker exec -i hive-server hive -e "SHOW DATABASES;"

# Show tables in food_delivery
docker exec -i hive-server hive -e "USE food_delivery; SHOW TABLES;"

# Preview rows
docker exec -i hive-server hive -e "USE food_delivery; SELECT order_id, restaurant_name, total, rating FROM orders LIMIT 5;"
```

---

### Step 5: Run MapReduce Job (Optional)

Compile the MapReduce Java package and submit the job to YARN:

```bash
# Build JAR
cd mapreduce
mvn clean package
cd ..

# Copy JAR to ResourceManager container and submit job
docker cp mapreduce/target/restaurant-analytics-1.0-SNAPSHOT.jar resourcemanager:/tmp/restaurant-analytics.jar
docker exec -it resourcemanager yarn jar /tmp/restaurant-analytics.jar RestaurantDriver
```

---

## 📁 Repository Structure

```
├── docker-compose.yml              # Cluster definition with simplified container names & amd64 platform
├── hadoop.env                      # Shared Hadoop & HDFS configuration environment variables
├── preprocessing.ipynb             # Data cleaning and feature engineering notebook
├── data/
│   ├── raw/                        # Raw Kaggle food delivery dataset
│   └── processed/                  # Cleaned dataset (orders_clean.csv)
├── hive/
│   ├── conf/
│   │   └── hive-site.xml           # Custom Hive configuration (fs.defaultFS, metastore, MR engine)
│   ├── setup_and_run_hive.sql      # All-in-one Hive setup + 12 analytical queries
│   ├── setup.sql                   # Table creation DDL script
│   ├── queries.sql                 # 12 analytical SQL queries
│   └── README.md                   # Detailed Hive technical documentation & viva guide
├── mapreduce/
│   ├── RestaurantDriver.java       # MapReduce job configuration and driver
│   ├── RestaurantMapper.java       # Mapper implementation
│   ├── RestaurantReducer.java      # Reducer aggregation logic
│   └── pom.xml                     # Maven build configuration
└── results/
    ├── hive_output/                # Query output text dumps
    └── mapreduce_output/           # MapReduce job results
```

---

## 🛑 Stop Cluster

```bash
# Stop containers
docker compose down

# Stop and reset volume data (fresh start)
docker compose down -v
```
