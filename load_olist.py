"""
Loads the raw Olist CSVs into a local DuckDB file (olist.duckdb) under the `raw` schema.
Run once before your first `dbt build`:  python load_olist.py
"""
import duckdb, glob, os, pathlib

DB = "olist.duckdb"
DATA = pathlib.Path("data")

# csv filename stem  ->  raw table name
TABLES = {
    "olist_customers_dataset":            "customers",
    "olist_geolocation_dataset":          "geolocation",
    "olist_order_items_dataset":          "order_items",
    "olist_order_payments_dataset":       "order_payments",
    "olist_order_reviews_dataset":        "order_reviews",
    "olist_orders_dataset":               "orders",
    "olist_products_dataset":             "products",
    "olist_sellers_dataset":              "sellers",
    "product_category_name_translation":  "product_category_translation",
}

con = duckdb.connect(DB)
con.execute("CREATE SCHEMA IF NOT EXISTS raw;")
for stem, tbl in TABLES.items():
    path = DATA / f"{stem}.csv"
    if not path.exists():
        raise FileNotFoundError(f"Missing {path}. Did you unzip data/ ?")
    con.execute(f"CREATE OR REPLACE TABLE raw.{tbl} AS "
                f"SELECT * FROM read_csv_auto('{path.as_posix()}', header=true);")
    n = con.execute(f"SELECT count(*) FROM raw.{tbl}").fetchone()[0]
    print(f"loaded raw.{tbl:<28} {n:>9,} rows")
con.close()
print("\nDone. raw schema is ready in olist.duckdb")
