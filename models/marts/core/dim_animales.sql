{{ 
    config(
        materialized='table',
        description='Dimensión de Animales. Contiene el estado más reciente y limpio de cada animal.'
    ) 
}}

with staging as (
    select * from {{ ref('stg_rescue__animales') }}
    -- Candado Anti-Multiplicación
    qualify row_number() over (
        partition by animal_id 
        order by ingested_at desc
    ) = 1
),

final_dimension as (
    select
        animal_key as dim_animal_key,
        animal_id as natural_animal_id,
        nombre_animal,
        especie_animal,
        raza_animal,
        color_animal,
        sexo_animal,
        fecha_nacimiento,
        peso_kg,
        tiene_microchip,
        condicion_ingreso,
        actualizado_en_origen_at
    from staging
),

-- CREAMOS EL ANIMAL FANTASMA PARA LOS 10 REGISTROS HUÉRFANOS
unknown_record as (
    select
        {{ dbt_utils.generate_surrogate_key(["'-1'"]) }} as dim_animal_key,
        '-1' as natural_animal_id,
        'Animal No Registrado' as nombre_animal,
        'Desconocido' as especie_animal,
        'Desconocido' as raza_animal,
        'Desconocido' as color_animal,
        'Desconocido' as sexo_animal,
        null as fecha_nacimiento,
        null as peso_kg,
        null as tiene_microchip,
        'Error en Origen' as condicion_ingreso,
        current_timestamp() as actualizado_en_origen_at
)

-- Unimos la tabla real con nuestro registro salvavidas
select * from final_dimension
union all
select * from unknown_record