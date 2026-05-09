import snowflake.connector
import os

print("Conectando a Snowflake...")

# 1. TUS DATOS DE CONEXIÓN EXACTOS
conn = snowflake.connector.connect(
    account="PGZQVEH-TU13834",
    user="Betancor13bis",
    password="z:xkEX-D6qAPePy", 
)
cursor = conn.cursor()

# 2. CONFIGURACIÓN DEL ENTORNO
cursor.execute("USE ROLE ACCOUNTADMIN")
cursor.execute("USE WAREHOUSE COMPUTE_WH")
cursor.execute("USE DATABASE DEV_BRONZE")
cursor.execute("USE SCHEMA RAW")

# Creamos la "carpeta" temporal en Snowflake
cursor.execute("CREATE STAGE IF NOT EXISTS STAGE_INGESTA_LOCAL")

# 3. BUSCAMOS LOS ARCHIVOS EN TU ESCRITORIO
escritorio = os.path.join(os.path.expanduser("~"), "Desktop")
ruta_carpeta = os.path.join(escritorio, "Rescue_animal")

archivos_tablas = {
    "adopters.csv": "ADOPTERS",
    "animales.csv": "ANIMALES",
    "donations.csv": "DONATIONS",
    "movimientos.csv": "MOVIMIENTOS",
    "sedes.csv": "SEDES",
    "visitas_medicas.csv": "VISITAS_MEDICAS",
    "zip_codes.csv": "ZIP_CODES"
}

print(f"\nBuscando CSVs en: {ruta_carpeta}\n" + "-"*40)

# 4. EL BUCLE INCREMENTAL (PRODUCCIÓN)
for archivo, tabla in archivos_tablas.items():
    ruta_completa = os.path.join(ruta_carpeta, archivo)
    
    if os.path.exists(ruta_completa):
        print(f"Procesando {archivo}...")
        ruta_sql = ruta_completa.replace("\\", "/")
        
        try:
            # A. Subimos el archivo al Stage
            cursor.execute(f"PUT 'file://{ruta_sql}' @STAGE_INGESTA_LOCAL OVERWRITE = TRUE")

            # B. Creamos la tabla SOLO si no existe (Inferencia de esquema)
            cursor.execute(f"""
                CREATE TABLE IF NOT EXISTS {tabla}
                USING TEMPLATE (
                    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
                    FROM TABLE(
                        INFER_SCHEMA(
                            LOCATION=>'@STAGE_INGESTA_LOCAL/{archivo}.gz',
                            FILE_FORMAT=>'FORMATO_CSV_GENERAL'
                        )
                    )
                )
            """)

            # C. Aseguramos que exista la columna técnica sin romper si ya existe de ayer
            cursor.execute(f"ALTER TABLE {tabla} ADD COLUMN IF NOT EXISTS _LOADED_AT TIMESTAMP_NTZ")

            # D. Volcamos los datos (Snowflake sabe qué archivos ya procesó y no duplica a lo loco)
            cursor.execute(f"""
                COPY INTO {tabla}
                FROM @STAGE_INGESTA_LOCAL/{archivo}.gz
                FILE_FORMAT = (FORMAT_NAME = 'FORMATO_CSV_GENERAL')
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                ON_ERROR = 'CONTINUE'
            """)

            # E. Estampamos la hora exacta SOLO a los registros que acaban de entrar sin fecha
            cursor.execute(f"UPDATE {tabla} SET _LOADED_AT = CURRENT_TIMESTAMP() WHERE _LOADED_AT IS NULL")
            
            print(f"✅ ¡{tabla} procesada con éxito en modo incremental!")
            
        except Exception as e:
            print(f"⚠️ Error al procesar {archivo}: {e}")
            
    else:
        print(f"❌ No se encontró el archivo: {archivo}")

cursor.close()
conn.close()

print("-" * 40 + "\n🎯 ¡Carga de Producción finalizada!")
input("Presiona ENTER para salir...")