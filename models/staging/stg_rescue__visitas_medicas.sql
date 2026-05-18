{{ config(materialized='view') }}

with source as (
    select * from {{ ref('snp_visitas_medicas') }}
    where dbt_valid_to is null
),

cleaned as (
    select
        -- 1. CLAVES (IDs)
        visita_medica_key, -- La clave subrogada profesional que viene del snapshot
        cast(id_visita as string) as visita_id,
        cast(id_animal as string) as animal_id,
        cast(id_sede as string) as sede_id,

        -- 2. FECHAS
        -- Separamos fecha y hora por si el analista solo quiere ver días
        cast(fecha_visita as timestamp) as fecha_visita,

        -- 3. INFORMACIÓN MÉDICA (Limpieza de texto)
        upper(trim(motivo)) as motivo_visita, -- Normalizamos a MAYÚSCULAS para evitar duplicados
        
        case 
            when lower(trim(diagnostico)) like '%null%' or diagnostico is null 
            then 'Pendiente de diagnóstico'
            else initcap(trim(diagnostico))
        end as diagnostico,

        -- 4. FINANZAS (Limpieza de dinero)
        -- Usamos abs() por si hay algún coste negativo por error
        cast(abs(coste_visita) as decimal(10,2)) as coste_visita,

        -- 5. METADATOS DE CONTROL
        cast(_loaded_at as timestamp) as ingested_at

    from source
)

select * from cleaned