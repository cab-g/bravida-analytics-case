with sellers as (
    select * from {{ ref('stg_sellers') }}
),

locations as (
    select * from {{ ref('dim_locations') }}
),

final as (
    select
        s.seller_id,
        s.zip_code_prefix,
        s.city,
        s.state,
        l.latitude,
        l.longitude
    from sellers s
    left join locations l on s.zip_code_prefix = l.zip_code_prefix
)

select * from final
