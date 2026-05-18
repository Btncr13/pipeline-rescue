{{ config(materialized='view') }}

with source as (
    select * from {{ ref('map_especies_reglas') }}
)

select * from source