-- The raw geolocation table has many rows per zip_code_prefix (multiple lat/lng readings).
-- Joining it directly fans out row counts. We deduplicate here by averaging lat/lng per prefix,
-- taking the most common city name as the canonical label.
-- 598 rows fall outside Brazil's bounding box (lat -34 to 5, lng -74 to -35) — filtered
-- before averaging so bad readings don't distort coordinates for valid zips.

with source as (
    select * from {{ ref('stg_geolocation') }}
),

valid as (
    select *
    from source
    where latitude  between -34 and 5
      and longitude between -74 and -35
),

final as (
    select
        zip_code_prefix,
        avg(latitude)  as latitude,
        avg(longitude) as longitude,
        state,
        -- most frequent city name for this zip prefix
        mode() within group (order by city) as city
    from valid
    group by zip_code_prefix, state
)

select * from final
