{% snapshot snp_visitas_medicas %}

{{
    config(
      target_database=('PROD_BRONZE' if target.name == 'PROD' else 'DEV_BRONZE'),
      target_schema='SNAPSHOTS',
      unique_key='id_visita', 
      strategy='check',
      check_cols='all',
    )
}}

select
    *,
    {{ dbt_utils.generate_surrogate_key([
        'id_visita'
    ]) }} as visita_medica_key,
    from {{ source('rescue', 'visitas_medicas') }}

{% endsnapshot %}