{{ config(materialized='view') }}

with source as (
    select * from {{ source('rescue', 'movimientos') }}
),

cleaned as (
    select
        -- CLAVES
        {{ dbt_utils.generate_surrogate_key(['id_movimiento']) }} as movimiento_key,
        cast(id_movimiento as string) as movimiento_id,
        
        -- CLAVES FORÁNEAS (Foreign Keys)
        cast(id_animal as string) as animal_id,
        -- Algunos movimientos como los abandonos podrían no tener usuario, lo dejamos preparado
        cast(id_usuario as string) as user_id,
        cast(id_sede as string) as sede_id,

        -- CATEGORÍAS Y EVENTOS
        upper(trim(tipo_evento)) as tipo_evento, -- ENTRADA, SALIDA, TRASLADO
        initcap(trim(metodo_evento)) as metodo_evento, -- Adopción, Rescate, etc.

        -- MÉTRICAS
        cast(coste_operacion as decimal(10,2)) as coste_operacion,

        -- FECHAS
        cast(fecha_evento as timestamp) as fecha_evento

    from source
)

select * from cleaned