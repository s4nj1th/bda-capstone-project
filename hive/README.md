# Big Data Analytics Pipeline — Hadoop + YARN + MapReduce + Hive

## Overview

This module implements a complete, end-to-end Big Data pipeline for food delivery analytics using:

- **Apache Hadoop 3.3.6** (HDFS + YARN) — Distributed file storage and cluster resource management
- **Apache Hive 3.1.3** (MapReduce engine) — SQL-on-Hadoop analytics layer
- **Java MapReduce** — Custom restaurant performance analysis job
- **ORC Columnar Storage** — High-performance managed Hive tables
- **Docker Compose** — Containerised, reproducible cluster environment

### Pipeline Architecture

```
orders_clean.csv (Local)
        |
        v
   HDFS Upload
        |
   /food_delivery/input/          (Java MapReduce input)
   /user/bda/food_delivery/clean/ (Hive external table source)
        |
        v
  +------------------------------------------+
  |          Hadoop YARN Cluster             |
  |  ResourceManager + NodeManager           |
  +------------------------------------------+
        |                    |
        v                    v
  Java MapReduce         Hive 3.1.3
  (RestaurantDriver)     (MapReduce engine)
        |                    |
        v                    v
  HDFS Output           ORC Managed Table
  (part-r-00000)        + 12 Analytical Queries
```

---

## Prerequisites

### 1. Software Requirements

| Software | Version | Notes |
|---|---|---|
| **Docker Desktop** | 4.x or later | Must be running before any command |
| **Docker Compose** | v2.x (bundled with Docker Desktop) | Use `docker compose` (not `docker-compose`) |
| **Java JDK** | 11 or later (host machine) | Required to compile MapReduce code |
| **Git** | Any recent version | For cloning the repository |

### 2. Docker Image Versions (Auto-pulled on first run)

| Image | Version | Purpose |
|---|---|---|
| `apache/hadoop` | `3.3.6` | NameNode, DataNode, ResourceManager, NodeManager |
| `apache/hive` | `3.1.3` | Hive Metastore + CLI |

> **Important**: Docker pulls these images automatically on first `docker compose up`. Total download size is approximately **2.5 GB**. Ensure a stable internet connection for first-time setup.

### 3. System Requirements

- **RAM**: Minimum 8 GB available (cluster uses ~4 GB)
- **Disk**: Minimum 5 GB free space for Docker images and volumes
- **OS**: macOS (Apple Silicon M1/M2/M3 or Intel), Linux, or Windows with WSL2

---

## Repository Setup

### Clone the Repository

```bash
git clone https://github.com/s4nj1th/bda-capstone-project.git
cd bda-capstone-project
```

### Verify Hadoop JARs Exist (Required for Java Compilation)

```bash
ls /tmp/bda_hadoop_jars/
```

If the directory does not exist or is empty, extract Hadoop JARs from the Docker image:

```bash
mkdir -p /tmp/bda_hadoop_jars
docker run --rm -v /tmp/bda_hadoop_jars:/dest apache/hadoop:3.3.6 bash -c "cp /opt/hadoop/share/hadoop/common/*.jar /opt/hadoop/share/hadoop/common/lib/*.jar /opt/hadoop/share/hadoop/mapreduce/*.jar /opt/hadoop/share/hadoop/yarn/*.jar /dest/ 2>/dev/null; echo done"
```

---

## Step-by-Step Execution Guide

> Run every command from inside the `bda-capstone-project/` root directory.

---

### PHASE 1: Start the Cluster

**Step 1.1 — Stop and remove any previous containers (Clean Slate):**

```bash
docker compose down -v --remove-orphans
```

This removes all containers AND named volumes. Your HDFS data is wiped. This guarantees a clean, reproducible start.

**Step 1.2 — Start all services:**

```bash
docker compose up -d
```

This starts 5 containers:
- `namenode` — HDFS NameNode (port 9870)
- `datanode` — HDFS DataNode
- `resourcemanager` — YARN ResourceManager (port 8088)
- `nodemanager` — YARN NodeManager
- `hive-server` — Hive Metastore (port 9083)

**Step 1.3 — Wait for NameNode safe mode to exit:**

```bash
sleep 30
docker compose exec -T namenode hdfs dfsadmin -safemode wait
```

Expected output: `Safe mode is OFF`

**Step 1.4 — Verify all 5 containers are running:**

```bash
docker compose ps
```

Expected: All 5 containers show `running`.

**Step 1.5 — Verify YARN NodeManager is ready:**

```bash
docker compose exec -T resourcemanager yarn node -list
```

Expected output contains: `nodemanager:XXXXX  RUNNING`

---

### PHASE 2: Set Up HDFS

**Step 2.1 — Create HDFS directory structure:**

```bash
docker compose exec -T namenode bash -c "hdfs dfs -mkdir -p /user/hive/warehouse && hdfs dfs -chmod -R 777 /user/hive && hdfs dfs -mkdir -p /tmp/hive && hdfs dfs -chmod -R 777 /tmp/hive && hdfs dfs -mkdir -p /food_delivery/input && hdfs dfs -mkdir -p /user/bda/food_delivery/clean && echo 'HDFS directories created' && hdfs dfs -ls /"
```

**Step 2.2 — Upload the data file to HDFS:**

```bash
docker cp data/processed/orders_clean.csv namenode:/tmp/orders_clean.csv
```

```bash
docker compose exec -T namenode bash -c "hdfs dfs -put -f /tmp/orders_clean.csv /food_delivery/input/orders_clean.csv && hdfs dfs -put -f /tmp/orders_clean.csv /user/bda/food_delivery/clean/orders_clean.csv && echo 'Upload done:' && hdfs dfs -ls /food_delivery/input/"
```

Expected: `orders_clean.csv` listed in both HDFS paths.

---

### PHASE 3: Java MapReduce on YARN

**Step 3.1 — Compile Java source files:**

```bash
mkdir -p mapreduce/target/classes
javac --release 8 -cp "/tmp/bda_hadoop_jars/*" -d mapreduce/target/classes mapreduce/*.java
```

> Warnings about `source value 8 is obsolete` are expected and harmless.

**Step 3.2 — Package into executable JAR:**

```bash
printf "Main-Class: RestaurantDriver\n\n" > /tmp/bda_manifest.txt
jar cvfm mapreduce/target/restaurant-analysis.jar /tmp/bda_manifest.txt -C mapreduce/target/classes .
```

**Step 3.3 — Copy JAR into NameNode container:**

```bash
docker cp mapreduce/target/restaurant-analysis.jar namenode:/tmp/restaurant-analysis.jar
```

**Step 3.4 — Clear old output directory on HDFS (if any):**

```bash
docker compose exec -T namenode hdfs dfs -rm -r -f /food_delivery/output/restaurant_performance
```

**Step 3.5 — Submit MapReduce job to YARN:**

```bash
docker compose exec -T namenode hadoop jar /tmp/restaurant-analysis.jar RestaurantDriver
```

A successful run shows:
```
map 100% reduce 100%
Job completed successfully
```

**Step 3.6 — View MapReduce results on HDFS:**

```bash
docker compose exec -T namenode hdfs dfs -cat /food_delivery/output/restaurant_performance/part-r-00000
```

Output columns (tab-separated):
```
Restaurant_ID   Restaurant_Name   Total_Orders   Total_Revenue   Avg_Order_Value   Avg_KPT_mins   Avg_Rider_Wait_mins
```

---

### PHASE 4: Hive + MapReduce — Full SQL Pipeline

**Step 4.1 — Run the complete Hive SQL script (table setup + all 12 queries):**

```bash
mkdir -p results/hive_output
```

```bash
docker exec -i hive-server hive --hiveconf hive.cli.print.header=true --hiveconf hive.execution.engine=mr -f /tmp/setup_and_run_hive.sql > results/hive_output/all_queries.txt 2>&1
```

This takes approximately **2 to 4 minutes**. Each query launches a MapReduce job visible as `map = 100%, reduce = 100%` in the output.

**Step 4.2 — Verify output:**

```bash
cat results/hive_output/all_queries.txt | tail -50
```

The last few lines should show Q12 results:
```
restaurant_name   order_count   avg_rating   avg_kpt
Swaad             6282          4.43         17.78
Aura Pizzas       14417         4.32         17.08
```

---

### PHASE 5: Individual Hive Queries (Run One by One)

Each command can be run independently at any time after the tables are created in Phase 4.

**Q1 — Total number of orders:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT COUNT(*) AS total_orders FROM orders;"
```

**Q2 — Orders by restaurant:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, COUNT(*) AS order_count FROM orders GROUP BY restaurant_name ORDER BY order_count DESC;"
```

**Q3 — Orders by delivery status:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT order_status, COUNT(*) AS cnt FROM orders GROUP BY order_status ORDER BY cnt DESC;"
```

**Q4 — Total revenue by restaurant (delivered orders only):**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, SUM(total) AS total_revenue FROM orders WHERE order_status = 'Delivered' GROUP BY restaurant_name ORDER BY total_revenue DESC;"
```

**Q5 — Average order value (AOV) by restaurant:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, ROUND(AVG(total), 2) AS avg_order_value FROM orders WHERE order_status = 'Delivered' GROUP BY restaurant_name ORDER BY avg_order_value DESC;"
```

**Q6 — Top 10 highest value orders:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT order_id, restaurant_name, total FROM orders WHERE order_status = 'Delivered' ORDER BY total DESC LIMIT 10;"
```

**Q7 — Kitchen prep time (KPT) metrics per restaurant:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt, MAX(kpt_duration_minutes) AS max_kpt, MIN(kpt_duration_minutes) AS min_kpt FROM orders WHERE kpt_duration_minutes IS NOT NULL GROUP BY restaurant_name ORDER BY avg_kpt DESC;"
```

**Q8 — Average rider wait time per restaurant:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, ROUND(AVG(rider_wait_time_minutes), 2) AS avg_rider_wait FROM orders WHERE rider_wait_time_minutes IS NOT NULL GROUP BY restaurant_name ORDER BY avg_rider_wait DESC;"
```

**Q9 — Distance-based order behaviour:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT distance, COUNT(*) AS order_count, ROUND(AVG(total), 2) AS avg_order_value FROM orders GROUP BY distance ORDER BY order_count DESC;"
```

**Q10 — Customer rating and review count by restaurant:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS num_ratings FROM orders WHERE rating IS NOT NULL GROUP BY restaurant_name ORDER BY avg_rating DESC;"
```

**Q11 — Most frequent customer complaints:**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT customer_complaint_tag, COUNT(*) AS complaint_count FROM orders WHERE customer_complaint_tag IS NOT NULL AND customer_complaint_tag <> '' GROUP BY customer_complaint_tag ORDER BY complaint_count DESC;"
```

**Q12 — High-performing restaurants (volume > 500 and rating >= 4.0):**

```bash
docker exec -it hive-server hive -e "USE food_delivery; SELECT restaurant_name, COUNT(*) AS order_count, ROUND(AVG(rating), 2) AS avg_rating, ROUND(AVG(kpt_duration_minutes), 2) AS avg_kpt FROM orders WHERE order_status = 'Delivered' GROUP BY restaurant_name HAVING COUNT(*) > 500 AND AVG(rating) >= 4.0 ORDER BY avg_rating DESC;"
```

---

### PHASE 6: Stop the Cluster

**Option A — Stop containers only (preserve HDFS data for later):**

```bash
docker compose stop
```

Resume later with:
```bash
docker compose start
```

**Option B — Full teardown (delete everything):**

```bash
docker compose down -v
```

---

## Expected Results Summary

| Query | Key Finding |
|---|---|
| Q1 | **21,341** total orders in dataset |
| Q2 | Aura Pizzas leads with **14,548 orders** |
| Q3 | **21,131** Delivered, 158 Rejected, 25 Returned |
| Q4 | Aura Pizzas generates **Rs 1.06 Crore** revenue |
| Q5 | Tandoori Junction has highest AOV at **Rs 870.98** |
| Q6 | Top order value is **Rs 12,663** (Aura Pizzas) |
| Q7 | Tandoori Junction has highest avg KPT: **21.26 mins** |
| Q8 | The Chicken Junction has highest rider wait: **7.26 mins** |
| Q9 | Peak delivery distance is **2km** (3,558 orders) |
| Q10 | Masala Junction is top rated: **4.83 stars** |
| Q11 | Top complaint: **"Non-refunded complaint"** (157 cases) |
| Q12 | High performers: **Swaad** (4.43 stars) and **Aura Pizzas** (4.32 stars) |

---

## Challenges Faced and Solutions

### Challenge 1: NameNode Stuck in Safe Mode

**Symptom:**
```
Cannot create directory. Name node is in safe mode.
```

**Cause:** NameNode enters safe mode on startup until it validates all DataNode block reports. On restart with corrupted volumes it can get stuck permanently.

**Solution:**
```bash
docker compose exec -T namenode hdfs dfsadmin -safemode leave
```
Or do a clean restart:
```bash
docker compose down -v && docker compose up -d && sleep 30
```

---

### Challenge 2: YARN NodeManager Not Registering

**Symptom:** `yarn node -list` returns empty or shows `LOST` state.

**Cause:** NodeManager takes 15 to 30 seconds after startup to register with the ResourceManager.

**Solution:** Wait 30 seconds after `docker compose up -d` before submitting any jobs.
```bash
sleep 30 && docker compose exec -T resourcemanager yarn node -list
```

---

### Challenge 3: MapReduce Job Fails — ClassNotFoundException

**Symptom:**
```
java.lang.ClassNotFoundException: RestaurantDriver
```

**Cause:** JAR was not compiled with the correct classpath, or the `Main-Class` manifest entry is missing.

**Solution:** Recompile using the exact commands in Phase 3. Ensure `/tmp/bda_hadoop_jars/` is populated first.

---

### Challenge 4: Hive CTAS Fails with ClassCastException on YARN

**Symptom:**
```
java.lang.ClassCastException: GetFileInfoRequestProto cannot be cast to com.google.protobuf.Message
```

**Cause:** Hive 3.1.3 bundles Hadoop 3.1.0 internally, which uses unshaded Protobuf 2.5.0. Hadoop 3.3.6 on the YARN cluster uses shaded Protobuf 3.x (`org.apache.hadoop.thirdparty.protobuf.*`). When Hive submits a MapReduce job to YARN, the ApplicationMaster container's classpath mixes both Protobuf versions, causing a ClassCastException.

**Solution:** Set `mapreduce.framework.name=local` in `hive/conf/mapred-site.xml`. This runs Hive MapReduce tasks inside the Hive container JVM, reading from and writing to HDFS without submitting to YARN. The YARN cluster is separately demonstrated by the Java MapReduce job (RestaurantDriver) which submits directly to YARN and succeeds.

---

### Challenge 5: Hive 4.0.0 Has No MapReduce Engine

**Symptom:** Switching to `apache/hive:4.0.0` and running `hive -f script.sql` returns `No current connection` or exits silently.

**Cause:** Hive 4.0.0 removed the MapReduce execution engine entirely (HIVE-21779). The `hive` CLI in 4.0.0 is a wrapper around `beeline` which requires a JDBC connection string. The `hive.execution.engine=mr` setting is no longer supported.

**Solution:** Use `apache/hive:3.1.3` which retains the MapReduce engine. The `docker-compose.yml` in this project is already set to `apache/hive:3.1.3`.

---

### Challenge 6: Hive Container Name Conflict on Restart

**Symptom:**
```
Error response from daemon: Conflict. The container name "/hive-server" is already in use.
```

**Cause:** A stopped but not removed container with the same name exists in Docker.

**Solution:**
```bash
docker rm -f hive-server && docker compose up -d hive-server
```

---

### Challenge 7: `zsh: command not found: #` When Pasting Commands

**Symptom:** Pasting a block of commands that includes `# comment lines` into zsh terminal causes errors.

**Cause:** zsh does not support inline `#` comments in interactive terminal sessions (only in scripts).

**Solution:** Paste only the actual executable commands without comment lines. Or save everything to a `.sh` file and run it with `bash script.sh`.

---

## File Structure Reference

```
bda-capstone-project/
├── docker-compose.yml              # Cluster definition (Hadoop + Hive)
├── hadoop.env                      # Hadoop XML properties injected as env vars
├── data/
│   └── processed/
│       └── orders_clean.csv        # Cleaned input dataset
├── mapreduce/
│   ├── RestaurantDriver.java       # YARN job submitter
│   ├── RestaurantMapper.java       # CSV parser and emitter
│   ├── RestaurantReducer.java      # Aggregator (revenue, KPT, rider wait)
│   ├── pom.xml                     # Maven build descriptor (Hadoop 3.3.6)
│   └── target/
│       └── restaurant-analysis.jar # Compiled JAR (generated, not committed)
├── hive/
│   ├── conf/
│   │   ├── hive-site.xml           # Hive metastore + warehouse + MR engine config
│   │   ├── core-site.xml           # HDFS NameNode URI
│   │   ├── hdfs-site.xml           # Replication factor, permissions
│   │   ├── mapred-site.xml         # mapreduce.framework.name=local
│   │   └── yarn-site.xml           # ResourceManager address
│   └── setup_and_run_hive.sql      # Full pipeline SQL (tables + 12 queries)
└── results/
    └── hive_output/
        └── all_queries.txt         # Full output of all 12 Hive queries (generated)
```
