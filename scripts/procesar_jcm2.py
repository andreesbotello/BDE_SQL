import os
import sys
from pathlib import Path
import psycopg2
from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, CODIGO_MUNICIPIO

# Project directory structure
SCRIPTS_DIR = Path(__file__).resolve().parent
SQL_FILE_PATH = SCRIPTS_DIR / "procesar_jcm2.sql"
VALIDATE_FILE_PATH = SCRIPTS_DIR / "validar_jcm2.sql"
REPORT_FILE_PATH = SCRIPTS_DIR / "reporte_limpieza.sql"

def procesar_modelo_jcm2():
    print("=====================================================================")
    print("PROCESADOR DE MODELO DE DATOS Y REFINAMIENTO DE GEOMETRÍAS (jcm2)")
    print("=====================================================================")

    # 1. Read and format SQL processing file
    if not SQL_FILE_PATH.exists():
        print(f"[ERROR] No se encuentra el archivo SQL de procesamiento: {SQL_FILE_PATH}")
        sys.exit(1)

    print(f"Leyendo {SQL_FILE_PATH.name} y reemplazando marcador de municipio (CODIGO: {CODIGO_MUNICIPIO})...")
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Dynamic replacement of the municipality code placeholder
    sql_content = sql_content.replace("{{CODIGO_MUNICIPIO}}", CODIGO_MUNICIPIO)

    # 2. Connect to PostGIS database and run the main SQL sequence
    conn = None
    try:
        print(f"Conectando a base de datos '{DB_NAME}' en {DB_HOST}:{DB_PORT}...")
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        conn.autocommit = True
        cur = conn.cursor()

        print("Ejecutando sentencias SQL para construir el esquema jcm2...")
        cur.execute(sql_content)
        print("[OK] Sentencias ejecutadas con éxito.")

        # 3. Read and execute SQL validation file
        if not VALIDATE_FILE_PATH.exists():
            print(f"[WARNING] No se encuentra el archivo SQL de validación: {VALIDATE_FILE_PATH}")
        else:
            print(f"\nEjecutando consultas de validación desde {VALIDATE_FILE_PATH.name}...")
            with open(VALIDATE_FILE_PATH, "r", encoding="utf-8") as f:
                validate_content = f.read()

            cur.execute(validate_content)
            resultados = cur.fetchall()

            # 4. Generate quality control and quantity reports
            print("\n=====================================================================")
            print("INFORME DE CONTROL DE CALIDAD Y REGISTROS IMPORTADOS (jcm2)")
            print("=====================================================================")

            todos_validos = True
            for fila in resultados:
                tabla, total, invalidos = fila
                print(f" - jcm2.{tabla.ljust(18)} : {total} registros.")
                
                if invalidos is not None:
                    if invalidos > 0:
                        print(f"   [ALERTA] La tabla jcm2.{tabla} contiene {invalidos} geometrías NO válidas.")
                        todos_validos = False
                    else:
                        print(f"   - Integridad geométrica: Todas las geometrías son válidas.")
                else:
                    print(f"   - Integridad geométrica: No aplica (tabla alfanumérica).")

            print("\n=====================================================================")
            if todos_validos:
                print("[OK] Integridad geométrica: PASADO (0 geometrías inválidas en capas espaciales).")
            else:
                print("[ALERTA] Integridad geométrica: FALLADO (se encontraron geometrías inválidas).")
            print("=====================================================================")

        # 3b. Read and execute cleaning report to analyze transition metrics
        
        if REPORT_FILE_PATH.exists():
            print(f"\nEjecutando informe de limpieza y depuración desde {REPORT_FILE_PATH.name}...")
            with open(REPORT_FILE_PATH, "r", encoding="utf-8") as f:
                report_content = f.read().replace("{{CODIGO_MUNICIPIO}}", CODIGO_MUNICIPIO)
            
            cur.execute(report_content)
            limpieza_resultados = cur.fetchall()
            
            print("\n=========================================================================================================================")
            print("REPORTE DETALLADO DE LIMPIEZA Y DEPURACIÓN DE DATOS (jcm1 -> jcm2)")
            print("=========================================================================================================================")
            print(f"{'Tabla'.ljust(18)} | {'Total jcm1 (500m)'.ljust(18)} | {'Total jcm2 (Depurado)'.ljust(22)} | {'Inválidos'.ljust(10)} | {'Multipartes'.ljust(11)} | {'Slivers <0.5'.ljust(12)} | {'Incoherencias'.ljust(13)}")
            print("-" * 121)
            
            for fila in limpieza_resultados:
                tabla, total_jcm1, total_jcm2, invalidos, multiparte, micro, incoherencias = fila
                print(f"{tabla.ljust(18)} | {str(total_jcm1).ljust(18)} | {str(total_jcm2).ljust(22)} | {str(invalidos).ljust(10)} | {str(multiparte).ljust(11)} | {str(micro).ljust(12)} | {str(incoherencias).ljust(13)}")
            
            print("=========================================================================================================================")

        cur.close()
        conn.close()

        print("\n=====================================================================")
        print("PROCESAMIENTO DE ESQUEMA jcm2 COMPLETADO CON ÉXITO")
        print("=====================================================================")

    except Exception as e:
        print(f"[ERROR] Falló la ejecución del procesamiento del modelo de datos: {e}")
        if conn:
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    procesar_modelo_jcm2()
