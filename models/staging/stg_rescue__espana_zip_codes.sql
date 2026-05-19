{{ config(materialized='view') }}

with source as (
    select * from {{ ref('espana_zip_codes') }}
),

-- 1. Creamos una capa intermedia para eliminar los códigos postales repetidos
deduplicated as (
    select * from source
    qualify row_number() over (
        partition by codigo_postal 
        order by municipio_nombre asc -- Nos quedamos con el primer pueblo alfabéticamente si hay repetidos
    ) = 1
),

cleaned as (
    select
        -- CLAVES
        {{ dbt_utils.generate_surrogate_key(['codigo_postal']) }} as zip_code_key,
        
        -- DATOS GEOGRÁFICOS
        lpad(cast(codigo_postal as string), 5, '0') as zip_code,
        initcap(trim(municipio_nombre)) as city_name,
        
        case substr(lpad(cast(codigo_postal as string), 5, '0'), 1, 2)
            when '01' then 'Álava'
            when '02' then 'Albacete'
            when '03' then 'Alicante'
            when '04' then 'Almería'
            when '05' then 'Ávila'
            when '06' then 'Badajoz'
            when '07' then 'Baleares'
            when '08' then 'Barcelona'
            when '09' then 'Burgos'
            when '10' then 'Cáceres'
            when '11' then 'Cádiz'
            when '12' then 'Castellón'
            when '13' then 'Ciudad Real'
            when '14' then 'Córdoba'
            when '15' then 'A Coruña'
            when '16' then 'Cuenca'
            when '17' then 'Girona'
            when '18' then 'Granada'
            when '19' then 'Guadalajara'
            when '20' then 'Gipuzkoa'
            when '21' then 'Huelva'
            when '22' then 'Huesca'
            when '23' then 'Jaén'
            when '24' then 'León'
            when '25' then 'Lleida'
            when '26' then 'La Rioja'
            when '27' then 'Lugo'
            when '28' then 'Madrid'
            when '29' then 'Málaga'
            when '30' then 'Murcia'
            when '31' then 'Navarra'
            when '32' then 'Ourense'
            when '33' then 'Asturias'
            when '34' then 'Palencia'
            when '35' then 'Las Palmas'
            when '36' then 'Pontevedra'
            when '37' then 'Salamanca'
            when '38' then 'Santa Cruz de Tenerife'
            when '39' then 'Cantabria'
            when '40' then 'Segovia'
            when '41' then 'Sevilla'
            when '42' then 'Soria'
            when '43' then 'Tarragona'
            when '44' then 'Teruel'
            when '45' then 'Toledo'
            when '46' then 'Valencia'
            when '47' then 'Valladolid'
            when '48' then 'Bizkaia'
            when '49' then 'Zamora'
            when '50' then 'Zaragoza'
            when '51' then 'Ceuta'
            when '52' then 'Melilla'
            else 'Desconocido'
        end as province_name,

    from deduplicated -- 2. CAMBIADO AQUÍ: Ahora lee de la lista ya limpia sin duplicados
)

select * from cleaned