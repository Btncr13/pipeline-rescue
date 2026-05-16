{% macro clean_money(column_name) %}
    TRY_CAST(REPLACE(REPLACE(CAST({{ column_name }} AS STRING), '€', ''), ',', '.') AS NUMBER(10,2))
{% endmacro %}