{{ config(materialized='view') }}

with source as (
    select * from {{ source('rescue', 'donations') }}
),

-- 1. Parseamos el JSON para que Snowflake lo entienda como un objeto estructurado
parsed_json as (
    select
        transaction_id,
        cast(event_timestamp as timestamp) as donation_at,
        cast(event_timestamp as date) as donation_date,
        -- parse_json convierte el texto en un objeto navegable (Variant)
        parse_json(payload_donacion) as payload 
    from source
),

-- 2. Extraemos y limpiamos los campos
cleaned as (
    select
        -- CLAVE SUBROGADA
        {{ dbt_utils.generate_surrogate_key(['transaction_id']) }} as donation_key,
        
        -- IDs NATURALES
        cast(transaction_id as string) as transaction_id,
        -- Extraemos el user_id. Si viene null, se quedará como null (ideal para los anónimos)
        cast(payload:user_id as string) as user_id,
        
        -- FECHAS
        donation_at,
        donation_date,

        -- MÉTRICAS Y DIMENSIONES
        -- Extraemos y limpiamos el importe con nuestra macro
        {{ clean_money('payload:importe') }} as donation_amount,
        
        -- Limpiamos el método de pago: quitamos espacios (trim) y pasamos a mayúsculas
        upper(trim(cast(payload:metodo_pago as string))) as payment_method,

        -- EXTRACCIÓN ANIDADA (Nested JSON)
        -- Usamos el punto para navegar dentro del bloque "campaign"
        cast(payload:campaign.campaign_id as string) as campaign_id,
        cast(payload:campaign.campaign_name as string) as campaign_name,
        cast(payload:campaign.budget as decimal(10,2)) as campaign_budget

    from parsed_json
)

select * from cleaned