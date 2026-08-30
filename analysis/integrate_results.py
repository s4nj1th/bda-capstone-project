import pandas as pd
import numpy as np
import os
import json

def parse_mapreduce_output(mr_path):
    """
    Parses MapReduce TSV output. Handles both:
    1. Single prefix:  RestaurantName \t order_count=X ...
    2. Double prefix: RestaurantID \t RestaurantName \t order_count=X ...
    """
    rows = []
    with open(mr_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            
            key_val_parts = [p for p in parts if "=" in p]
            prefix_parts = [p for p in parts if "=" not in p]
            
            metrics = {}
            for p in key_val_parts:
                k, v = p.split("=", 1)
                try:
                    metrics[k] = float(v)
                except ValueError:
                    metrics[k] = v
            
            if len(prefix_parts) >= 2:
                metrics["restaurant_id"] = prefix_parts[0].strip()
                metrics["restaurant_name"] = prefix_parts[1].strip()
            elif len(prefix_parts) == 1:
                metrics["restaurant_name"] = prefix_parts[0].strip()
            else:
                continue
                
            rows.append(metrics)
            
    return pd.DataFrame(rows)

def validate_cross_engine(mr_df, clean_csv_path="data/processed/orders_clean.csv"):
    """
    Validates MapReduce metrics against raw cleaned dataset (emulating Hive query validation).
    Returns a validation summary dictionary.
    """
    validation_results = {"status": "SUCCESS", "metrics_validation": []}
    if not os.path.exists(clean_csv_path):
        validation_results["status"] = "SKIPPED_NO_CLEAN_DATA"
        return validation_results

    try:
        clean_df = pd.read_csv(clean_csv_path)
        for _, row in mr_df.iterrows():
            r_name = row["restaurant_name"]
            matched = clean_df[clean_df["Restaurant name"].str.strip() == r_name]
            if matched.empty:
                continue
            
            expected_count = len(matched)
            expected_rev = matched["Total"].sum()
            expected_kpt = matched["KPT duration (minutes)"].dropna().mean()
            expected_wait = matched["Rider wait time (minutes)"].dropna().mean()
            
            mr_count = row.get("order_count", 0)
            mr_rev = row.get("total_revenue", 0.0)
            mr_kpt = row.get("avg_kpt", 0.0)
            mr_wait = row.get("avg_rider_wait", 0.0)
            
            count_diff = abs(mr_count - expected_count)
            rev_diff_pct = abs(mr_rev - expected_rev) / expected_rev * 100 if expected_rev > 0 else 0
            kpt_diff = abs(mr_kpt - expected_kpt) if not np.isnan(expected_kpt) else 0
            wait_diff = abs(mr_wait - expected_wait) if not np.isnan(expected_wait) else 0
            
            validation_results["metrics_validation"].append({
                "restaurant_name": r_name,
                "count_match": count_diff == 0,
                "revenue_diff_pct": round(rev_diff_pct, 4),
                "kpt_diff_minutes": round(kpt_diff, 4),
                "wait_diff_minutes": round(wait_diff, 4)
            })
    except Exception as e:
        validation_results["status"] = f"ERROR: {str(e)}"

    return validation_results

def main():
    # 1. Locate MapReduce output file
    mr_path = "results/mapreduce_output/restaurant_performance.tsv"
    if not os.path.exists(mr_path):
        mr_path = "results/mapreduce_output/part-r-00000"

    print(f"[*] Reading MapReduce output from: {mr_path}")
    mr_df = parse_mapreduce_output(mr_path)

    # 2. Parse Hive query results (Q10 rating metrics)
    hive_path = "results/hive_output/q10_avg_rating.csv"
    print(f"[*] Reading Hive Q10 output from: {hive_path}")
    hive_rating = pd.read_csv(hive_path)
    hive_rating["restaurant_name"] = hive_rating["restaurant_name"].astype(str).str.strip()
    mr_df["restaurant_name"] = mr_df["restaurant_name"].astype(str).str.strip()

    # 3. Merge MapReduce metrics with Hive rating data
    combined = mr_df.merge(hive_rating, on="restaurant_name", how="left")

    # 4. Advanced Calculated Metrics
    total_platform_rev = combined["total_revenue"].sum()
    combined["revenue_share_pct"] = (combined["total_revenue"] / total_platform_rev * 100).round(2)
    
    # Efficiency ratio: Revenue / Avg KPT
    combined["efficiency_ratio"] = (combined["total_revenue"] / (combined["avg_kpt"] * combined["order_count"])).round(2)
    
    # Fill missing ratings or wait times with median for safe comparison
    combined["avg_rating_clean"] = combined["avg_rating"].fillna(combined["avg_rating"].median())
    combined["avg_kpt_clean"] = combined["avg_kpt"].fillna(combined["avg_kpt"].median())
    combined["avg_wait_clean"] = combined["avg_rider_wait"].fillna(combined["avg_rider_wait"].median())

    # 5. Operational Bottlenecks: high KPT + high rider wait time
    kpt_med = combined["avg_kpt_clean"].median()
    wait_med = combined["avg_wait_clean"].median()
    combined["kpt_flag"] = combined["avg_kpt_clean"] > kpt_med
    combined["wait_flag"] = combined["avg_wait_clean"] > wait_med
    combined["bottleneck"] = combined["kpt_flag"] & combined["wait_flag"]

    # 6. Growth Opportunities: high customer rating + lower order volume
    rating_med = combined["avg_rating_clean"].median()
    count_med = combined["order_count"].median()
    combined["growth_opportunity"] = (combined["avg_rating_clean"] >= rating_med) & (combined["order_count"] < count_med)

    # Clean up temporary helper columns before export
    display_cols = ["restaurant_name", "order_count", "total_revenue", "revenue_share_pct",
                    "avg_order_value", "avg_kpt", "avg_rider_wait", "avg_rating", "bottleneck", "growth_opportunity"]
    
    # 7. Export combined scorecard
    os.makedirs("results", exist_ok=True)
    scorecard_path = "results/combined_restaurant_scorecard.csv"
    combined.to_csv(scorecard_path, index=False)

    # 8. Perform Cross-Engine Validation
    validation_report = validate_cross_engine(mr_df)
    validation_path = "results/validation_report.json"
    with open(validation_path, "w") as f:
        json.dump(validation_report, f, indent=2)

    # 9. Generate Executive JSON Summary
    executive_summary = {
        "total_restaurants": len(combined),
        "total_orders": int(combined["order_count"].sum()),
        "total_platform_revenue": float(combined["total_revenue"].sum()),
        "avg_platform_order_value": float(round(combined["total_revenue"].sum() / combined["order_count"].sum(), 2)),
        "bottleneck_restaurants": combined[combined["bottleneck"]]["restaurant_name"].tolist(),
        "growth_opportunity_restaurants": combined[combined["growth_opportunity"]]["restaurant_name"].tolist()
    }
    summary_path = "results/executive_summary.json"
    with open(summary_path, "w") as f:
        json.dump(executive_summary, f, indent=2)

    print("\n" + "="*80)
    print("          INTEGRATED RESTAURANT SCORECARD (MEMBER 4 - ENHANCED)")
    print("="*80)
    print(combined[display_cols].to_string(index=False))

    print("\n" + "-"*80)
    print("  OPERATIONAL BOTTLENECKS (KPT > Median & Rider Wait > Median)")
    print("-" * 80)
    bottlenecks = combined[combined["bottleneck"]]
    if not bottlenecks.empty:
        print(bottlenecks[["restaurant_name", "order_count", "avg_kpt", "avg_rider_wait", "avg_rating"]].to_string(index=False))
    else:
        print("  No restaurants exceed both KPT and Rider Wait medians simultaneously.")

    print("\n" + "-"*80)
    print("  GROWTH OPPORTUNITIES (Rating >= Median & Order Volume < Median)")
    print("-" * 80)
    growth = combined[combined["growth_opportunity"]]
    if not growth.empty:
        print(growth[["restaurant_name", "order_count", "revenue_share_pct", "avg_rating", "avg_order_value"]].to_string(index=False))
    else:
        print("  No growth opportunities identified with current criteria.")

    print("\n" + "="*80)
    print(f"[+] Scorecard saved: {scorecard_path}")
    print(f"[+] Validation report saved: {validation_path}")
    print(f"[+] Executive summary saved: {summary_path}")

if __name__ == "__main__":
    main()
