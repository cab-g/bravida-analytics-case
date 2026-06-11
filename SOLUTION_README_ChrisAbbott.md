# Bravida Analytics Case — Solution Notes

## Business question

The commercial team wants to understand delivery performance and order value by seller and by region, and to see clearly where delivery is slipping against the dates customers were promised.

- **Order value by seller** — `fct_order_items` has `item_price` and `seller_id`; group by seller for revenue
- **Order value by region** — `fct_order_items` carries `customer_state` and `seller_state`; cut by either
- **Delivery slippage** — `fct_orders` has `is_late`, `days_late`, `estimated_delivery_at` vs `delivered_at`; filter to `order_status = 'delivered'`
- **Distance as a factor** — `fct_order_items` has `distance_km` (haversine, seller to customer zip centroid); join to `fct_orders` to correlate distance with lateness

---

## Project structure

```
models/
  staging/
    stg_orders                        one row per order, timestamps cast and renamed
    stg_order_items                   one row per (order_id, order_item_id)
    stg_order_payments                one row per (order_id, payment_sequential)
    stg_order_reviews                 one row per review
    stg_customers                     one row per customer_id (per-order identifier)
    stg_sellers                       one row per seller
    stg_products                      one row per product, typos fixed
    stg_product_category_translation  Portuguese to English category mapping
    stg_geolocation                   zip prefix to lat/lng, many rows per prefix

  marts/
    fct_orders                        order grain — delivery performance, payment, review
    fct_order_items                   item grain — seller, product, revenue, distance
    dim_sellers                       seller location enriched with lat/lng
    dim_customers                     one row per real person, enriched with lat/lng
    dim_products                      product attributes with English category
    dim_locations                     deduplicated geolocation, one row per zip prefix
```

Staging is a clean contract on top of raw. Nothing outside staging references `raw.*` directly.

---

## Modelling decisions

- **Two fact tables.**
  - Delivery timestamps live at order level; seller and product detail live at item level
  - `fct_orders` — order grain, delivery performance, payment and review context
  - `fct_order_items` — item grain, seller and product detail, revenue per line, seller-to-customer distance
  - They join on `order_id`
- **Delivery stage lags.**
  - `fct_orders` breaks the journey into three stages: approval, fulfilment (seller to carrier), delivery (carrier to customer)
  - Carrier leg dominates at 9.2 days avg — slippage investigation should start there, not with seller fulfilment (2.7 days)
- **`is_late` scoped to delivered orders.**
  - Cancelled and in-progress orders are included in the fact but explicitly excluded from the late flag to avoid miscounting
- **`total_item_value` not `total_payment_value` for order value.**
  - Payment diverges from item total in both directions for ~13% of orders — higher could be fees or margin, lower could be vouchers or discounts
  - `total_item_value` is consistent across 87% of orders and is the safer measure; `total_payment_value` is retained but documented as unreliable for value analysis
- **`customer_unique_id` as the customer key.**
  - `customer_id` is a per-order identifier — same person gets a new ID each order
  - `dim_customers` deduplicates on `customer_unique_id`, the stable cross-order identifier
- **Geolocation deduplicated into `dim_locations`.**
  - Raw table has many rows per zip prefix — joining directly fans out row counts
  - 598 rows fall outside Brazil's bounding box and are filtered before averaging; `mode()` picks the canonical city name where multiple spellings exist for the same prefix
  - `dim_locations` feeds `dim_sellers` and `dim_customers` with clean lat/lng
- **`distance_km` on `fct_order_items`.**
  - Haversine distance between seller and customer zip centroids — zip prefix grain, not routing precision
  - ~0.5% of seller zips and ~1.9% of customer zips have no geolocation match; those rows get null distance
- **Duplicate reviews.**
  - 87 orders have more than one review, several with conflicting scores
  - Decision: latest `review_creation_date` per order, `max(review_score)` as same-day tiebreaker
- **8 delivered orders with no `delivered_at`.**
  - Excluded from delivery metrics by the `is_late` logic
- **Product column typos.**
  - `product_name_lenght` and `product_description_lenght` corrected in `stg_products`

---

## Testing

- **`not_null` and `unique` on every PK** — grain contract; if either fails nothing downstream can be trusted
- **`not_null` on FKs** — catches orphaned rows that would silently drop out of joins
- **`relationships` on `seller_id` and `product_id` in `fct_order_items`** — verifies FK values exist in the target dim, not just that they are populated
- **`accepted_values` on `order_status`** — documents the known enum; alerts if a new status appears
- **`equal_rowcount` on `fct_orders` vs `stg_orders` and `fct_order_items` vs `stg_order_items`** — catches silent fan-out or row loss from joins
- **No `unique` on `stg_order_reviews.order_id`** — 87 duplicates are known and documented, not a test failure
- **No tests on nullable analytical fields** — `review_score`, `days_late`, `distance_km` can legitimately be null; documented in column descriptions

---

## Deferred decisions

- **Seller-level late delivery attribution** — all items in an order share the same delivery timestamps; `seller_missed_shipping_limit` is a proxy but order-level lateness cannot be attributed to a single seller without carrier tracking data
- **Region hierarchy** — `dim_locations` provides state but no macro-region grouping (Sul, Sudeste, Nordeste etc.); a region mapping above state level would improve geographic analysis
- **Review sentiment** — comment title and body are included in `fct_orders` but not analysed; NLP alongside score would give a richer satisfaction signal
- **Snowflake compatibility** — `distinct on` used in `fct_orders` and `dim_customers` is DuckDB/PostgreSQL syntax; the production replacement on Snowflake would be `row_number() over (partition by ... order by ...)` with a `where rn = 1` filter
