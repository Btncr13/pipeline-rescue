{{ config(materialized='view') }}

with source as (                                                -- Leemos del snapshot y nos quedamos solo con la versión "actual"
    select * from {{ ref('snp_adopters') }}
    where dbt_valid_to is null
),

cleaned as (
    select
        -- 1. Claves
        user_key, 
        cast(id_usuario as string) as user_id,

        -- 2. Información de Identidad (Deduplicación de Nombres y Edades)
       case 
            when lower(trim(nombre_completo)) like '%null%' then 'Anónimo' -- Antes era null
            when lower(trim(nombre_completo)) like '%error%' then 'Anónimo'
            when trim(nombre_completo) = '' or nombre_completo is null then 'Anónimo'
            else initcap(trim(regexp_replace(nombre_completo, '[0-9]', '')))
        end as nombre_completo,
        
        case 
            when upper(trim(genero)) in ('FEMENINO', 'F', 'MUJER') then 'FEMENINO'
            when upper(trim(genero)) in ('MASCULINO', 'M', 'HOMBRE') then 'MASCULINO'
            else 'DESCONOCIDO'
        end as genero_usuario,

        case 
            when try_cast(fecha_nacimiento as date) is null then null
            when datediff('year', try_cast(fecha_nacimiento as date), current_date()) > 100 then null
            when try_cast(fecha_nacimiento as date) > current_date() then null
            else try_cast(fecha_nacimiento as date)
        end as fecha_nacimiento,

        -- 3. Limpieza de Contacto (Teléfono y Email)
        case 
            when lower(trim(email)) = 'null' or email not like '%@%.%' then null
            else lower(trim(email))
        end as email,

        case
            when lower(trim(telefono)) = 'null' then null
            else 
                -- Lógica: 1. Solo números -> 2. Quitar prefijo 34 si existe -> 3. Validar 9 dígitos
                case 
                    when length(regexp_replace(regexp_replace(trim(telefono), '[^0-9]', ''), '^34', '')) = 9 
                        then regexp_replace(regexp_replace(trim(telefono), '[^0-9]', ''), '^34', '')
                    else null 
                end
        end as telefono,

        -- 4. Geografía (Código Postal)
        case 
            when lower(trim(codigo_postal)) = 'null' then null 
            -- Nos aseguramos de que solo haya números y tenga longitud 5
            when length(regexp_replace(trim(codigo_postal), '[^0-9]', '')) = 5 
                then regexp_replace(trim(codigo_postal), '[^0-9]', '')
            else null 
        end as codigo_postal,
        
        -- 5. Atributos de Perfil
        case 
            when lower(trim(profesion)) = 'null' then null 
            else initcap(trim(profesion)) 
        end as profesion,

        upper(trim(tipo_usuario)) as tipo_usuario, 
        upper(trim(canal_captacion)) as canal_captacion,
        
        -- Macro Global
        {{ cast_boolean('es_socio') }} as es_socio,
        
        try_cast(fecha_alta as date) as fecha_alta_at,

        -- 6. Metadatos Técnicos
        cast(_loaded_at as timestamp) as ingested_at

    from source
),

quality_filter as (
    select * from cleaned
    where 
        -- 1. Eliminamos registros "vacíos" (Sin nombre y sin contacto)
        not (nombre_completo is null and email is null and telefono is null)
        
        -- 2. Eliminamos nombres de prueba conocidos (Case Insensitive)
        and lower(nombre_completo) not in ('maria final', 'test', 'usuario prueba')
        and nombre_completo not like '%Prueba%'
)

select * from quality_filter