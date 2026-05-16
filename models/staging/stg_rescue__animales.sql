{{ config(materialized='view') }}

with source as (
    select * from {{ ref('snp_animales') }}
    where dbt_valid_to is null
),

map_razas as (
    select * from {{ ref('stg_rescue__map_razas') }}
),

map_reglas as (
    select * from {{ ref('stg_rescue__map_especies_reglas') }}
),

-- BLOQUE 1: Limpieza básica y pre-procesamiento
cleaned_base as (
    select
        s.animal_key,
        upper(replace(s.id_animal, ' ', '')) as animal_id,
        coalesce(upper(trim(s.nombre)), 'SIN NOMBRE') as nombre_animal,

        -- 1. Clasificación de especie original
        case
            when upper(trim(s.especie)) like 'PERR%' then 'PERRO'
            when upper(trim(s.especie)) like 'GAT%' then 'GATO'
            when upper(trim(s.especie)) like 'PAJ%' or upper(trim(s.especie)) like 'PÁJ%' then 'AVE'
            when upper(trim(s.especie)) like 'CON%' then 'CONEJO'
            when upper(trim(s.especie)) like 'HAMS%' then 'HAMSTER'
            when upper(trim(s.especie)) = 'PEZ' or upper(trim(s.especie)) like 'TORT%' or upper(trim(s.especie)) like 'DRAG%' then 'EXÓTICO'
            when upper(trim(s.especie)) in ('T-REX', 'UNICORNIO') then 'ERROR'
            else coalesce(upper(trim(s.especie)), 'DESCONOCIDO')
        end as especie_animal_origen,

        upper(trim(s.raza)) as raza_bruta,
        coalesce(upper(trim(s.color)), 'DESCONOCIDO') as color_animal,
        
        case 
            when upper(trim(s.genero)) in ('H', 'HEMBRA', 'FEMENINO', 'F') then 'HEMBRA'
            when upper(trim(s.genero)) in ('M', 'MACHO', 'MASCULINO') then 'MACHO'
            else 'DESCONOCIDO'
        end as sexo_animal,

        -- 2. Validación de Fecha de Nacimiento (Calendario + Futuro)
        case 
            when s.fecha_nacimiento_estimada is not null and try_cast(s.fecha_nacimiento_estimada as date) is null 
                then last_day(try_cast(left(s.fecha_nacimiento_estimada, 8) || '01' as date))
            when try_cast(s.fecha_nacimiento_estimada as date) > current_date()
                then null
            else try_cast(s.fecha_nacimiento_estimada as date)
        end as fecha_nacimiento_previa,

        {{ clean_numeric('s.peso_kg')}} as peso_bruto,
        {{ cast_boolean('s.tiene_microchip')}} as tiene_microchip,
        
        upper(trim(s.condicion_ingreso)) as condicion_ingreso,
        cast(s.fecha_actualizacion as timestamp) as actualizado_en_origen_at,
        s._loaded_at as ingested_at

    from source s
),

-- BLOQUE 2: Aplicación de reglas de negocio y cruces
final_model as (
    select
        b.animal_key,
        b.animal_id,
        b.nombre_animal,

        -- RESCATE DE ESPECIE: Si la seed tiene una especie corregida, la usamos. Si no, dejamos la del origen.
        coalesce(m.especie_correcta, b.especie_animal_origen) as especie_animal,

        -- LIMPIEZA DE RAZA: Usamos la raza limpia de la seed
        coalesce(m.raza_limpia, b.raza_bruta, 'DESCONOCIDO') as raza_animal,

        b.color_animal,
        b.sexo_animal,

        -- Validación de Edad Máxima (Seed 2)
        case 
            when datediff('year', b.fecha_nacimiento_previa, current_date()) > r.edad_maxima_biologica then null
            else b.fecha_nacimiento_previa
        end as fecha_nacimiento,

        -- Validación de Peso Dinámica (Seed 2)
        case 
            when b.peso_bruto between r.peso_min_kg and r.peso_max_kg then b.peso_bruto
            else null
        end as peso_kg,

        b.tiene_microchip,
        b.condicion_ingreso,
        b.actualizado_en_origen_at,
        b.ingested_at

    from cleaned_base b
    left join map_razas m 
        on b.especie_animal_origen = m.especie_origen 
        and b.raza_bruta = m.raza_original
    left join map_reglas r
        on coalesce(m.especie_correcta, b.especie_animal_origen) = r.especie
)

select * from final_model