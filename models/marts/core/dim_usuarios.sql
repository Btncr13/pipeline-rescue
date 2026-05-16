{{ 
    config(
        materialized='table',
        description='Dimensión de Usuarios. Contiene el Golden Record (deduplicado) y datos geográficos enriquecidos.'
    ) 
}}

with adopters as (
    select * from {{ ref('stg_rescue__usuarios') }}
),

zip_codes as (
    select * from {{ ref('stg_rescue__zip_codes') }}
),

-- 1. REGLA DE NEGOCIO: Deduplicación (Golden Record)
-- Forzamos a que el user_id sea ÚNICO. Si hay varios, nos quedamos con el último cargado.
deduplicated_adopters as (
    select * from adopters
    qualify row_number() over (
        partition by user_id   -- <--- AQUÍ ESTÁ LA MAGIA. Forzamos unicidad por ID.
        order by ingested_at desc 
    ) = 1
),
-- 2. ENRIQUECIMIENTO: Join con la tabla maestra de códigos postales
final_dimension as (
    select
        -- La clave subrogada definitiva para esta dimensión (PK)
        {{ dbt_utils.generate_surrogate_key(['a.user_id']) }} as dim_usuario_key,
        
        -- IDs y Datos Personales
        a.user_id as natural_user_id,
        a.nombre_completo,
        a.genero_usuario,
        a.fecha_nacimiento,
        
        -- Contacto
        a.email,
        a.telefono,
        
        -- Perfil en el Refugio
        a.profesion,
        a.tipo_usuario,
        a.canal_captacion,
        a.es_socio,
        a.fecha_alta_at,
        
        -- Geografía Enriquecida (Si no cruza, ponemos 'Desconocido' para evitar nulos en Power BI)
        a.codigo_postal,
        coalesce(z.city_name, 'Desconocido') as ciudad,
        coalesce(z.province_name, 'Desconocido') as provincia,
        z.latitude,
        z.longitude
        
    from deduplicated_adopters a
    left join zip_codes z 
        on a.codigo_postal = z.zip_code
)

select * from final_dimension