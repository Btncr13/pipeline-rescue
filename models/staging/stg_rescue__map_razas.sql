{{ config(materialized='view') }}

with source as (
    select * from {{ ref('map_razas') }}
)

select * from source