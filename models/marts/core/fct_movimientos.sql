{{ 
    config(
        materialized='incremental',
        unique_key='movimiento_key',
        on_schema_change='fail'
    ) 
}}

-- 1. Leemos los movimientos nuevos
with movimientos as (
    select * from {{ ref('stg_rescue__movimientos') }}
    
    {% if is_incremental() %}
        -- Si es incremental, filtramos primero para no cruzar toda la historia
        where fecha_evento > (select max(fecha_evento) from {{ this }})
    {% endif %}
),

-- 2. Nos traemos las dimensiones para hacer el "Lookup"
dim_animales as (
    select dim_animal_key, natural_animal_id from {{ ref('dim_animales') }}
),

dim_usuarios as (
    select dim_usuario_key, natural_user_id from {{ ref('dim_usuarios') }}
),

dim_sedes as (
    select dim_sede_key, natural_sede_id from {{ ref('dim_sedes') }}
)

-- 3. Construimos el Hecho cruzando por el ID natural
select
    m.movimiento_key,
    
    -- Claves Foráneas (Traídas directamente de las dimensiones)
    coalesce(a.dim_animal_key, {{ dbt_utils.generate_surrogate_key(["'-1'"]) }}) as dim_animal_key,
    u.dim_usuario_key,
    s.dim_sede_key,

    -- IDs Naturales y Degeneradas
    m.movimiento_id as natural_movimiento_id,
    m.tipo_evento,
    m.metodo_evento,

    -- Métricas
    m.coste_operacion,

    -- Fechas
    m.fecha_evento,
    
    current_timestamp() as dbt_processed_at

from movimientos m
left join dim_animales a on m.animal_id = a.natural_animal_id
left join dim_usuarios u on m.user_id = u.natural_user_id
left join dim_sedes s on m.sede_id = s.natural_sede_id