# Member 4 — Integrated Business Analysis, Findings & Report Framework

This document details the integrated analytical findings, business recommendations, report narrative structure, and viva presentation checklist for **Member 4**.

---

## 1. Executive Summary & Integration Overview

Member 4 integrates the distributed batch computation results produced by Hadoop MapReduce (Member 2) with the SQL relational analytics produced by Apache Hive (Member 3) over the cleaned food delivery dataset (Member 1).

By merging MapReduce performance metrics (`order_count`, `total_revenue`, `avg_order_value`, `avg_kpt`, `avg_rider_wait`) with Hive feedback metrics (`avg_rating`), the integration script `analysis/integrate_results.py` generates `results/combined_restaurant_scorecard.csv` to evaluate platform-wide restaurant performance.

---

## 2. Integrated Restaurant Scorecard

| Restaurant Name | Order Count | Total Revenue (₹) | Avg Order Value (₹) | Avg KPT (min) | Avg Rider Wait (min) | Avg Rating | Bottleneck Flag | Growth Opportunity |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Aura Pizzas** | 14,548 | 10,751,617.42 | 739.04 | 17.08 | 4.94 | 4.32 | No | No (High Volume Leader) |
| **Swaad** | 6,332 | 3,545,521.86 | 559.94 | 17.77 | 4.51 | 4.43 | No | No (High Volume Leader) |
| **Dilli Burger Adda** | 227 | 101,709.62 | 448.06 | 19.41 | 5.09 | 4.18 | **YES** | No |
| **Tandoori Junction** | 154 | 133,665.95 | 867.96 | 21.26 | 6.18 | 4.65 | **YES** | **YES** |
| **The Chicken Junction**| 32 | 12,380.99 | 386.91 | 15.55 | 7.26 | 4.69 | No | **YES** |
| **Masala Junction** | 28 | 9,162.30 | 327.23 | 13.66 | 4.57 | 4.83 | No | **YES** |

---

## 3. Findings Framework

### Finding 1: Severe Operational Bottleneck at Tandoori Junction
- **Observed Result**: `Tandoori Junction` has the highest KPT duration on the platform (`21.26 minutes`) and high rider wait time (`6.18 minutes`), while maintaining the highest Average Order Value (`₹867.96`).
- **Interpretation**: Kitchen complexity or staffing constraints for premium tandoori preparation lead to severe dispatch delays. Drivers idle for over 6 minutes waiting for orders.
- **Operational Implication**: High-ticket orders are experiencing fulfillment friction, risking customer churn despite high ratings.

### Finding 2: High Customer Rating but Low Order Volume (Under-marketed Gems)
- **Observed Result**: `Masala Junction` (Rating `4.83/5`, `28` orders), `The Chicken Junction` (Rating `4.69/5`, `32` orders), and `Tandoori Junction` (Rating `4.65/5`, `154` orders) hold the top 3 customer ratings on the platform, yet represent under 1% of total platform volume.
- **Interpretation**: High culinary satisfaction and food quality exist, but discovery and marketing reach are bottlenecked.
- **Operational Implication**: The platform is missing high-margin customer retention opportunities by under-exposing top-rated partners.

### Finding 3: Fulfillment Bottleneck at Dilli Burger Adda
- **Observed Result**: `Dilli Burger Adda` exhibits `19.41 minutes` avg KPT and `5.09 minutes` avg rider wait time, accompanied by the lowest customer rating on the platform (`4.18/5`).
- **Interpretation**: Preparation delays directly degrade food quality (e.g., soggy burgers/fries), leading to lower customer satisfaction scores.
- **Operational Implication**: Preparation speed at fast-food outlets correlates strongly with customer ratings.

---

## 4. Data-Grounded Business Recommendations

1. **Kitchen Workflow Audit for Tandoori Junction & Dilli Burger Adda**:
   - *Action*: Require kitchen prep optimization and staggered rider dispatch for outlets where KPT exceeds 19 minutes.
2. **Featured Placement & Promo Campaign for High-Rating Outlets**:
   - *Action*: Launch in-app promotional banners and discount pushes for `Masala Junction` (4.83 rating) and `The Chicken Junction` (4.69 rating) to scale their order volume.
3. **Dynamic Rider Staging for Extended Wait Times**:
   - *Action*: Adjust rider allocation algorithms to delay dispatch by +5 minutes for outlets with proven high KPT to minimize rider idle time.

---

## 5. Report Structure & Demo Script

### 17-Section Report Structure
1. **Introduction**: Overview of food delivery analytics architecture (HDFS → MapReduce + Hive → Python Integration).
2. **Problem Statement**: Platform operational bottlenecks, kitchen prep variance, and merchant performance evaluation.
3. **Motivation**: Leveraging Big Data distributed frameworks (Hadoop/Hive) for processing high-cardinality multi-attribute order datasets.
4. **Dataset Description**: Kaggle Food Delivery dataset (21,321 order records).
5. **Architecture Diagram**: End-to-end data pipeline diagram.
6–10. **MapReduce Specifications**: Mapper, Reducer, and Driver Java code breakdown (Member 2).
11. **Input & Output Formats**: Sample raw CSV row and processed MapReduce TSV record.
12–13. **Execution & UI Screenshots**: HDFS Web UI (9870), YARN Web UI (8088), Hive CLI logs.
14–16. **Hive Analytics**: DDL table definitions, SerDe configurations, and 12 analytical SQL queries (Member 3).
17. **Conclusion & Recommendations**: Integrated findings and platform operational strategy (Member 4).

### Demo Run Order
1. **Member 1**: Demonstrates data cleaning (`clean_data.py`) and HDFS file upload (`hdfs dfs -ls /user/bda/food_delivery/clean`).
2. **Member 2**: Runs MapReduce driver job and demonstrates job completion in YARN UI (`http://localhost:8088`).
3. **Member 3**: Executes representative Hive SQL queries in Hive CLI (`hive -f hive/queries.sql`).
4. **Member 4**: Executes `python3 analysis/integrate_results.py`, presents `combined_restaurant_scorecard.csv`, and highlights findings & recommendations.

---

## 6. Viva Preparation Checklist for Member 4

- **Q: Why combine MapReduce and Hive outputs in Python instead of doing everything in Hive?**
  - *Answer*: MapReduce handles low-level distributed batch aggregation (custom map-reduce logic for multi-column metrics without database overhead), while Hive provides structured relational SQL queries. Python integrates both outputs to apply threshold rules (median flagging) across heterogeneous compute layers.
- **Q: What is the difference between average of averages vs true weighted average?**
  - *Answer*: Computing average of restaurant averages weighs each restaurant equally regardless of volume. Our Reducer sums total revenue and total order count per restaurant before dividing, maintaining mathematical correctness.
- **Q: How does the script handle operational bottlenecks?**
  - *Answer*: By comparing each restaurant's KPT and rider wait times against platform median thresholds to isolate outlets experiencing both kitchen delays and driver idling.
