{{ config(materialized='table') }}

with source as (
    select * from {{ ref('stg_rescue__donations') }}
)

select
    -- Generamos la clave subrogada para conectar con los hechos
    {{ dbt_utils.generate_surrogate_key(['campaign_id']) }} as dim_campana_key,
    campaign_id as natural_campaign_id,
    initcap(trim(campaign_name)) as campaign_name,
    cast(campaign_budget as float) as campaign_budget

from source
-- Nos quedamos con una sola fila por cada campaña para limpiar el presupuesto
qualify row_number() over (
    partition by campaign_id 
    order by donation_at desc
) = 1