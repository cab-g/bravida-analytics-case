with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select
        order_id,
        customer_id,
        order_status,
        purchased_at,
        handed_to_carrier_at,
        delivered_at,
        estimated_delivery_at
    from {{ ref('stg_orders') }}
),

customers as (
    select
        customer_id,
        customer_unique_id,
        zip_code_prefix as customer_zip_code_prefix,
        city            as customer_city,
        state           as customer_state
    from {{ ref('stg_customers') }}
),

sellers as (
    select
        seller_id,
        zip_code_prefix as seller_zip_code_prefix,
        city            as seller_city,
        state           as seller_state
    from {{ ref('stg_sellers') }}
),

seller_locations as (
    select zip_code_prefix, latitude as seller_lat, longitude as seller_lng
    from {{ ref('dim_locations') }}
),

customer_locations as (
    select zip_code_prefix, latitude as customer_lat, longitude as customer_lng
    from {{ ref('dim_locations') }}
),

products as (
    select
        product_id,
        product_category_name,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        product_photos_qty
    from {{ ref('stg_products') }}
),

translations as (
    select
        product_category_name,
        category_name_english
    from {{ ref('stg_product_category_translation') }}
),

final as (
    select
        -- keys
        oi.order_id,
        oi.order_item_id,
        oi.seller_id,
        oi.product_id,
        o.customer_id,

        -- order context
        o.order_status,
        o.purchased_at,

        -- seller shipping deadline
        oi.shipping_limit_at,

        -- seller missed their shipping deadline
        case
            when oi.shipping_limit_at is not null and o.handed_to_carrier_at > oi.shipping_limit_at
            then true else false
        end as seller_missed_shipping_limit,

        -- item value
        oi.item_price,
        oi.freight_value,

        -- product attributes
        coalesce(t.category_name_english, p.product_category_name) as product_category,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        p.product_photos_qty,

        -- seller location
        s.seller_city,
        s.seller_state,
        s.seller_zip_code_prefix,

        -- customer location
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,

        -- seller-to-customer distance (haversine, km)
        -- null where seller or customer zip has no geolocation match (~0.5% and ~1.9% respectively)
        2 * 6371 * asin(sqrt(
            power(sin(radians(cl.customer_lat - sl.seller_lat) / 2), 2) +
            cos(radians(sl.seller_lat)) * cos(radians(cl.customer_lat)) *
            power(sin(radians(cl.customer_lng - sl.seller_lng) / 2), 2)
        )) as distance_km

    from order_items oi
    left join orders            o  on oi.order_id              = o.order_id
    left join sellers           s  on oi.seller_id             = s.seller_id
    left join customers         c  on o.customer_id            = c.customer_id
    left join products          p  on oi.product_id            = p.product_id
    left join translations      t  on p.product_category_name  = t.product_category_name
    left join seller_locations  sl on s.seller_zip_code_prefix = sl.zip_code_prefix
    left join customer_locations cl on c.customer_zip_code_prefix = cl.zip_code_prefix
)

select * from final
