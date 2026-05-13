{{ config(materialized='view') }}

with source as (
    select * from {{ source('rescue', 'sedes') }}
),

cleaned as (
    select
        -- CLAVES
        {{ dbt_utils.generate_surrogate_key(['id_sede']) }} as sede_key,
        cast(id_sede as string) as sede_id,

        -- INFORMACIÓN BÁSICA (Limpieza de textos y nulos)
        -- initcap() pone solo la primera letra en mayúscula de cada palabra
        initcap(trim(nombre_sede)) as nombre_sede,
        
        -- Si no hay tipo, le ponemos un valor por defecto
        coalesce(initcap(trim(tipo_instalacion)), 'No Definido') as tipo_instalacion,

        -- MÉTRICAS (Limpieza de números)
        -- abs() convierte los números negativos en positivos
        abs(cast(capacidad_maxima as integer)) as capacidad_maxima,

        -- CONTACTO Y DIRECCIÓN
        initcap(trim(direccion)) as direccion,
        initcap(trim(ciudad)) as ciudad,
        cast(codigo_postal as string) as codigo_postal,
        
        -- Quitamos los guiones de los teléfonos para que sean todos iguales
        replace(cast(telefono as string), '-', '') as telefono,
        initcap(trim(responsable_sede)) as responsable_sede,

        -- ESTADO (Limpieza de Booleanos)
        case 
            when lower(trim(es_activa)) in ('true', 'sí', 'si', 't', '1') then TRUE
            else FALSE
        end as is_active

    from source
)

select * from cleaned