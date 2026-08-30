import pandas as pd
import numpy as np
import os

def main():
    # 1. Parse MapReduce output
    mr_path = "results/mapreduce_output/restaurant_performance.tsv"
    if not os.path.exists(mr_path):
        mr_path = "results/mapreduce_output/part-r-00000"

    print(f"[*] Reading MapReduce output from: {mr_path}")
    rows = []
    with open(mr_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            name = parts[0].strip()
            metrics = {"restaurant_name": name}
            for p in parts[1:]:
                if "=" in p:
                    k, v = p.split("=", 1)
                    metrics[k] = float(v)
            rows.append(metrics)

    mr_df = pd.DataFrame(rows)

    # 2. Parse Hive query results (Q10 avg rating)
    hive_path = "results/hive_output/q10_avg_rating.csv"
    print(f"[*] Reading Hive Q10 output from: {hive_path}")
    hive_rating = pd.read_csv(hive_path)
    hive_rating["restaurant_name"] = hive_rating["restaurant_name"].str.strip()

    # 3. Merge MapReduce metrics with Hive rating data
    combined = mr_df.merge(hive_rating, on="restaurant_name", how="left")

    # 4. Operational Bottlenecks: high KPT + high rider wait time
    kpt_med = combined["avg_kpt"].median()
    wait_med = combined["avg_rider_wait"].median()
    combined["kpt_flag"] = combined["avg_kpt"] > kpt_med
    combined["wait_flag"] = combined["avg_rider_wait"] > wait_med
    combined["bottleneck"] = combined["kpt_flag"] & combined["wait_flag"]

    # 5. Growth Opportunities: high customer rating + low order volume
    rating_med = combined["avg_rating"].median()
    count_med = combined["order_count"].median()
    combined["growth_opportunity"] = (combined["avg_rating"] >= rating_med) & (combined["order_count"] < count_med)

    # 6. Export combined scorecard
    os.makedirs("results", exist_ok=True)
    scorecard_path = "results/combined_restaurant_scorecard.csv"
    combined.to_csv(scorecard_path, index=False)

    print("\n" + "="*70)
    print("          INTEGRATED RESTAURANT SCORECARD (MEMBER 4)")
    print("="*70)
    print(combined[["restaurant_name", "order_count", "total_revenue", "avg_order_value", "avg_kpt", "avg_rider_wait", "avg_rating"]].to_string(index=False))

    print("\n" + "-"*70)
    print("  OPERATIONAL BOTTLENECKS (KPT > Median & Rider Wait > Median)")
    print("-" * 70)
    bottlenecks = combined[combined["bottleneck"]]
    if not bottlenecks.empty:
        print(bottlenecks[["restaurant_name", "order_count", "avg_kpt", "avg_rider_wait"]].to_string(index=False))
    else:
        print("  No restaurants exceed both KPT and Rider Wait medians simultaneously.")

    print("\n" + "-"*70)
    print("  GROWTH OPPORTUNITIES (Rating >= Median & Order Volume < Median)")
    print("-" * 70)
    growth = combined[combined["growth_opportunity"]]
    if not growth.empty:
        print(growth[["restaurant_name", "order_count", "avg_rating", "avg_order_value"]].to_string(index=False))
    else:
        print("  No growth opportunities identified with current criteria.")

    print("\n" + "="*70)
    print(f"[+] Successfully generated combined scorecard at: {scorecard_path}")

if __name__ == "__main__":
    main()
