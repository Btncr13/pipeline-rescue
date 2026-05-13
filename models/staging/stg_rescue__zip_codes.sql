{{ config(materialized='view') }}

with source as (
    select * from {{ source('rescue', 'zip_codes') }}
),

cleaned as (
    select
        -- CLAVES
        -- El código postal es el identificador único natural de esta tabla
        {{ dbt_utils.generate_surrogate_key(['zip_code']) }} as zip_code_key,
        
        -- DATOS GEOGRÁFICOS
        -- Aplicamos LPAD por si algún código de otra provincia perdió el cero inicial
        lpad(cast(zip_code as string), 5, '0') as zip_code,
        initcap(trim(city)) as city_name,
        initcap(trim(province)) as province_name,
        
        -- COORDENADAS
        cast(latitude as float) as latitude,
        cast(longitude as float) as longitude

    from source
)

select * from cleaned