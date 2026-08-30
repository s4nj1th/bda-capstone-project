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

## Quickstart & Pipeline Execution

### Step 1: Start the Cluster

```bash
docker compose up -d
```

Verify all 5 services are running:

```bash
docker compose ps
```

---

### Step 2: Upload Clean Data to HDFS

Upload `orders_clean.csv` to HDFS via the `namenode` container:

```bash
# 1. Create HDFS directories
docker exec -i namenode hdfs dfs -mkdir -p /user/bda/food_delivery/clean/
docker exec -i namenode hdfs dfs -mkdir -p /food_delivery/input/

# 2. Copy processed dataset to NameNode and upload to HDFS
docker cp data/processed/orders_clean.csv namenode:/tmp/orders_clean.csv
docker exec -i namenode hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/orders_clean.csv
docker exec -i namenode hdfs dfs -put -f /tmp/orders_clean.csv /food_delivery/input/orders_clean.csv

# 3. Verify HDFS files
docker exec -i namenode hdfs dfs -ls /user/bda/food_delivery/clean/
```

---

### Step 3: Run Apache Hive Analytics Pipeline

Execute the table setup (External OpenCSV staging + ORC managed table) and all 12 analytical queries directly via the Hive CLI:

```bash
# 1. Copy the SQL file into the container
docker cp hive/setup_and_run_hive.sql hive-server:/tmp/setup_and_run_hive.sql

# 2. Execute the script in Hive (output to terminal)
docker exec -it hive-server hive -f /tmp/setup_and_run_hive.sql

# Or save the results directly to results file:
mkdir -p results/hive_output
docker exec -i hive-server hive -f /tmp/setup_and_run_hive.sql > results/hive_output/all_queries.txt
```

#### Interactive Hive Shell

```bash
docker exec -it hive-server hive
```

---

### Step 4: Run MapReduce Job (Optional)

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
├── docker-compose.yml              # Cluster definition with simplified container names
├── hadoop.env                      # Shared Hadoop configuration environment variables
├── preprocessing.ipynb             # Data cleaning and feature engineering notebook
├── data/
│   ├── raw/                        # Raw Kaggle food delivery dataset
│   └── processed/                  # Cleaned dataset (orders_clean.csv)
├── hive/
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
docker compose down
```
