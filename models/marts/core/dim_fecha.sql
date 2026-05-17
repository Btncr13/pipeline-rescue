{{ 
    config(
        materialized='table'
    ) 
}}

{{ dbt_date.get_date_dimension("1950-01-01", "2030-12-31") }}