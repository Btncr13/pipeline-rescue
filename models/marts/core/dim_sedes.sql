{{ 
    config(
        materialized='table',
        description='Dimensión de Sedes y Refugios.'
    ) 
}}

with staging as (
    select * from {{ ref('stg_rescue__sedes') }}
),

final_dimension as (
    select
        sede_key as dim_sede_key,
        sede_id as natural_sede_id,
        
        nombre_sede,
        tipo_instalacion,
        capacidad_maxima,
        
        -- Contacto y Ubicación
        direccion,
        ciudad,
        codigo_postal,
        telefono,
        responsable_sede,
        is_active
        
    from staging
)

select * from final_dimension