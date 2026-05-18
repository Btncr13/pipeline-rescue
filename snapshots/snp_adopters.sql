{% snapshot snp_adopters %}

{{
    config(
        target_database=target.database,
        target_schema='snapshots',
        unique_key='user_key',
        strategy='check',
        check_cols=['email', 'telefono', 'tipo_usuario', 'es_socio']
    )
}}

with source_data as (               -- Creamos una CTE para generar la columna animal_key que utilizamos como clave unica
    select 
        *,
        {{ dbt_utils.generate_surrogate_key([
            'id_usuario', 
            'nombre_completo',
            "coalesce(cast(fecha_nacimiento as string), '1900-01-01')" 
        ]) }} as user_key
    from {{ source('rescue', 'adopters') }}
)

select * from source_data

{% endsnapshot %}