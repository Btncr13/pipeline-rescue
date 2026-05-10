{# 
    Estandariza campos de texto tipo 'SI/NO' o '1/0' a valores booleanos (TRUE/FALSE).
    - TRIM: Elimina espacios en blanco accidentales.
    - UPPER: Convierte a mayúsculas para que la comparación sea insensible a la capitalización.
    - ELSE NULL: Si viene un valor inesperado, lo marca como nulo para posterior limpieza.
#}

{% macro cast_boolean(column_name) %}
    CASE 
        WHEN UPPER(TRIM({{ column_name }})) IN ('SI', 'YES', '1', 'TRUE', 'T', 'Y') THEN TRUE 
        WHEN UPPER(TRIM({{ column_name }})) IN ('NO', '0', 'FALSE', 'F', 'N') THEN FALSE
        ELSE NULL 
    END
{% endmacro %}