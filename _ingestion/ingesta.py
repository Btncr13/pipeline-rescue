import snowflake.connector
import os

print("Conectando a Snowflake...")

# 1. TUS DATOS DE CONEXIÓN EXACTOS
conn = snowflake.connector.connect(
    account="TU_ACCOUNT_ID_AQUI",
    user="TU_USUARIO_AQUI",
    password="TU_CONTRASEÑA_AQUI",
)
cursor = conn.cursor()

# 2. CONFIGURACIÓN DEL ENTORNO (Usamos la capa que creamos antes)
cursor.execute("USE ROLE ACCOUNTADMIN")
cursor.execute("USE WAREHOUSE COMPUTE_WH")
cursor.execute("USE DATABASE DEV_BRONZE")
cursor.execute("USE SCHEMA RAW")

# Creamos la "carpeta" temporal en Snowflake si no existe
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

# 4. EL BUCLE QUE HACE TODO EL TRABAJO
for archivo, tabla in archivos_tablas.items():
    ruta_completa = os.path.join(ruta_carpeta, archivo)
    
    if os.path.exists(ruta_completa):
        print(f"Subiendo {archivo}...")
        
        # Adaptamos la ruta para que Snowflake la entienda (barras hacia adelante)
        ruta_sql = ruta_completa.replace("\\", "/")
        
        try:
            # Asegurar columna de Auditoría ---
            # Si la tabla ya existe, le añade la columna si no la tiene.
            # El DEFAULT asegura que cada fila nueva reciba la hora actual automáticamente.
            cursor.execute(f"""
                ALTER TABLE {tabla} 
                ADD COLUMN IF NOT EXISTS _INGESTED_AT TIMESTAMP_NTZ 
                DEFAULT CURRENT_TIMESTAMP()
            """)
            
            # Paso 1: Subir el archivo (PUT)
            cursor.execute(f"PUT 'file://{ruta_sql}' @STAGE_INGESTA_LOCAL OVERWRITE = TRUE")
            
            # Paso 2: Volcarlo en la tabla (COPY INTO) a prueba de balas
            cursor.execute(f"""
            COPY INTO {tabla}
            FROM @STAGE_INGESTA_LOCAL/{archivo}.gz
            FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"')
            ON_ERROR = 'CONTINUE'
            """)
            print(f"✅ ¡{tabla} lista!")
            
        except Exception as e:
            print(f"⚠️ Hubo un problema menor con {archivo}: {e}")
    else:
        print(f"❌ No encuentro el archivo {archivo} en la carpeta.")

# Cerramos las conexiones
cursor.close()
conn.close()
print("-" * 40 + "\n¡Carga terminada!")