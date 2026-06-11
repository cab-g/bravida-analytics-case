with orders as (
    select * from {{ ref('stg_orders') }}
),

items as (
    select
        order_id,
        count(*)            as item_count,
        sum(item_price)     as total_item_value,
        sum(freight_value)  as total_freight
    from {{ ref('stg_order_items') }}
    group by order_id
),

payments as (
    select
        order_id,
        sum(payment_value)                                          as total_payment_value,
        max(case when payment_sequential = 1 then payment_type end) as primary_payment_type,
        max(case when payment_type = 'voucher' then 1 else 0 end)   as has_voucher
    from {{ ref('stg_order_payments') }}
    group by order_id
),

reviews as (
    select distinct on (order_id)
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    from {{ ref('stg_order_reviews') }}
    order by order_id, review_created_at desc, review_score desc
),

customers as (
    select
        customer_id,
        city   as customer_city,
        state  as customer_state
    from {{ ref('stg_customers') }}
),

final as (
    select
        -- keys
        o.order_id,
        o.customer_id,

        -- order status
        o.order_status,

        -- timestamps
        o.purchased_at,
        o.approved_at,
        o.handed_to_carrier_at,
        o.delivered_at,
        o.estimated_delivery_at,

        -- delivery stage lags (in days)
        datediff('day', o.purchased_at, o.approved_at)          as approval_lag_days,
        datediff('day', o.approved_at, o.handed_to_carrier_at)  as fulfilment_lag_days,
        datediff('day', o.handed_to_carrier_at, o.delivered_at) as delivery_lag_days,
        datediff('day', o.estimated_delivery_at, o.delivered_at) as days_late,

        -- late flag — only meaningful for delivered orders
        case
            when o.order_status = 'delivered' and o.delivered_at > o.estimated_delivery_at
            then true else false
        end as is_late,

        -- order value
        i.item_count,
        i.total_item_value,
        i.total_freight,
        p.total_payment_value,

        -- payment
        p.primary_payment_type,
        p.has_voucher,

        -- review
        r.review_score,
        r.review_comment_title,
        r.review_comment_message,

        -- customer location
        c.customer_city,
        c.customer_state

    from orders o
    left join items    i on o.order_id = i.order_id
    left join payments p on o.order_id = p.order_id
    left join reviews  r on o.order_id = r.order_id
    left join customers c on o.customer_id = c.customer_id
)

select * from final
