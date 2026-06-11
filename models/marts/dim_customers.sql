with customers as (
    select * from {{ ref('stg_customers') }}
),

locations as (
    select * from {{ ref('dim_locations') }}
),

deduped as (
    -- stg_customers has one row per customer_id (per-order), not per person.
    -- A repeat customer appears multiple times. We take the latest record.
    select distinct on (customer_unique_id)
        customer_unique_id,
        zip_code_prefix,
        city,
        state
    from customers
    order by customer_unique_id, customer_id
),

final as (
    select
        d.customer_unique_id,
        d.zip_code_prefix,
        d.city,
        d.state,
        l.latitude,
        l.longitude
    from deduped d
    left join locations l on d.zip_code_prefix = l.zip_code_prefix
)

select * from final
