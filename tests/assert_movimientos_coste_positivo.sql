-- Este test valida una regla de negocio crítica:
-- El coste de una operación (movimiento) no debe ser negativo.
-- Si esta query devuelve alguna fila, significa que hay un error en el origen y dbt hará saltar la alerta.

select
    movimiento_key,
    natural_movimiento_id,
    tipo_evento,
    coste_operacion
from {{ ref('fct_movimientos') }}
where coste_operacion < 0