{{ 
    config(
        materialized='table'
    ) 
}}

{{ dbt_date.get_date_dimension("2025-05-01", run_started_at.strftime("%Y-%m-%d")) }}