import snowflake.connector
import os
from dotenv import load_dotenv # <-- 1. Importamos esto para leer el archivo .env

print("Conectando a Snowflake...")

load_dotenv() # <-- 2. Esta función busca el archivo .env y carga las contraseñas en memoria

# DATOS DE CONEXIÓN EXACTOS
conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),   # <-- 3. Usamos os.getenv() sin comillas dentro
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse="COMPUTE_WH",
    database="DEV_BRONZE",
    schema="RAW"
)
cursor = conn.cursor()

# Asegura que el Stage existe
cursor.execute("CREATE STAGE IF NOT EXISTS STAGE_INGESTA_LOCAL")

# BUSCAS LOS ARCHIVOS
escritorio = os.path.join(os.path.expanduser("~"), "Desktop")
ruta_carpeta = os.path.join(escritorio, "Rescue_animal")

print(f"\nBuscando CSVs en: {ruta_carpeta}\n" + "-"*40)

# BUCLE AUTOMÁTICO DE CARGA RAW
# Iteramos sobre todos los elementos (archivos/carpetas) que existan en la ruta indicada
for archivo in os.listdir(ruta_carpeta):
    # Filtro de seguridad: si el archivo no termina en .csv, lo saltamos y pasamos al siguiente
    if not archivo.endswith('.csv'):
        continue
        
    # Deducimos el nombre de la tabla eliminando la extensión '.csv' y convirtiendo a MAYÚSCULAS
    # Ejemplo: 'adopters.csv' -> 'ADOPTERS'
    tabla = archivo.replace('.csv', '').upper()
    
    # Construimos la ruta absoluta del archivo en nuestra máquina local
    ruta_completa = os.path.join(ruta_carpeta, archivo)
    
    # Snowflake requiere que las rutas de los archivos locales usen barras inclinadas hacia adelante '/'
    # Por defecto, Windows usa '\', así que hacemos el reemplazo para evitar errores de sintaxis
    ruta_sql = ruta_completa.replace("\\", "/")
    
    print(f"Procesando {archivo} en la tabla {tabla}...")
    
    try:
        # 1. Subimos el archivo al Stage
        cursor.execute(f"PUT 'file://{ruta_sql}' @STAGE_INGESTA_LOCAL OVERWRITE = TRUE")

        # 2. Vaciamos la tabla para que no se dupliquen filas si relanzamos el script
        cursor.execute(f"TRUNCATE TABLE {tabla}")

        # 3. Copiamos los datos (Tu lógica original que funcionaba)
        cursor.execute(f"""
            COPY INTO {tabla}
            FROM @STAGE_INGESTA_LOCAL/{archivo}.gz
            FILE_FORMAT = (FORMAT_NAME = 'FORMATO_CSV_GENERAL')
            MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
            ON_ERROR = 'CONTINUE'
            PURGE = TRUE
        """)

        # 4. Sello de tiempo para la auditoría técnica
        cursor.execute(f"UPDATE {tabla} SET _loaded_at = CURRENT_TIMESTAMP() WHERE _loaded_at IS NULL")

        print(f"✅ ¡{tabla} cargada con éxito y sin duplicados!")
        
    except Exception as e:
        print(f"⚠️ Error al procesar {archivo}: {e}")

# CIERRE DE CONEXIONES
# Es vital cerrar el cursor y la conexión para liberar los recursos de red y memoria.
cursor.close()
conn.close()

print("-" * 40 + "\n🎯 ¡Carga de Producción finalizada!")
input("Presiona ENTER para salir...")