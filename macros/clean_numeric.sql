{# 
    Esta macro se encarga de transformar una columna de texto en un número decimal.
    REPLACE: Cambia las comas por puntos para que Snowflake lo reconozca como decimal.
    TRY_CAST: Intenta convertir a NUMBER(10, 2). Si el valor no es numérico (ej. 'ERROR'), 
    devuelve NULL en lugar de romper la ejecución del pipeline.
#}

{% macro clean_numeric(column_name) %}
    TRY_CAST(REPLACE( {{ column_name }}, ',', '.') AS NUMBER(10, 2))
{% endmacro %}