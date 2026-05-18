select
    m.movimiento_key,
    m.natural_movimiento_id,
    m.fecha_evento,
    a.natural_animal_id,
    a.fecha_nacimiento
from {{ ref('fct_movimientos') }} m
inner join {{ ref('dim_animales') }} a 
    on m.dim_animal_key = a.dim_animal_key
where a.fecha_nacimiento is not null 
  and date(m.fecha_evento) < a.fecha_nacimiento