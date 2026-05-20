{{ config(materialized='incremental', unique_key='donation_key') }}

WITH donaciones AS (
    SELECT * FROM {{ ref('stg_rescue__donations') }}
),
usuarios AS (
    SELECT * FROM {{ ref('dim_usuarios') }}
)

SELECT
    d.donation_key,
    d.transaction_id,
    COALESCE(u.dim_usuario_key, '-1') AS usuario_key, 
    -- 1. Añadimos el puente hacia la nueva dimensión de campañas
    {{ dbt_utils.generate_surrogate_key(['d.campaign_id']) }} as campana_key,
    d.donation_date AS fecha_key,
    d.donation_amount AS importe,
    d.payment_method AS metodo_pago

FROM donaciones d
LEFT JOIN usuarios u ON d.user_id = u.natural_user_id






{% if is_incremental() %}
  WHERE d.donation_date > (SELECT MAX(fecha_key) FROM {{ this }})
{% endif %}








