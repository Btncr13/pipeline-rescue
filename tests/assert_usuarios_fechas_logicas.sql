select
    dim_usuario_key,
    natural_user_id,
    fecha_nacimiento,
    fecha_alta_at
from {{ ref('dim_usuarios') }}
where fecha_alta_at < fecha_nacimiento