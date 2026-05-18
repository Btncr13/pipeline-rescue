{% snapshot snp_animales %}

{{
    config(
        target_database=('PROD_BRONZE' if target.name == 'PROD' else 'DEV_BRONZE'),
        target_schema='snapshots',
        unique_key='animal_key',
        strategy='check',
        check_cols=['peso_kg', 'tiene_microchip', 'condicion_ingreso']
    )
}}

with source_data as (               -- Creamos una CTE para generar la columna animal_key que utilizamos como clave unica
    select 
        *,
        {{ dbt_utils.generate_surrogate_key([
            'id_animal', 
            'nombre', 
            'fecha_nacimiento_estimada'
        ]) }} as animal_key
    from {{ source('rescue', 'animales') }}
)

select * from source_data

{% endsnapshot %}