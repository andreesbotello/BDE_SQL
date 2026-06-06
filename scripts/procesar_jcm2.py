import os
import sys
from pathlib import Path
import psycopg2
from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, CODIGO_MUNICIPIO, SRID_PROYECTO

# Project directory structure
SCRIPTS_DIR = Path(__file__).resolve().parent
SQL_FILE_PATH = SCRIPTS_DIR / "procesar_jcm2.sql"
VALIDATE_FILE_PATH = SCRIPTS_DIR / "validar_jcm2.sql"
REPORT_FILE_PATH = SCRIPTS_DIR / "reporte_limpieza.sql"
CHECK_FILE_PATH = SCRIPTS_DIR / "validar_check_jcm2.sql"

def ejecutar_pruebas_check(conn):
    print("\n=====================================================================")
    print("EJECUTANDO PRUEBAS DE RESTRICCIONES CHECK (VALIDAR REGLAS DE NEGOCIO)")
    print("=====================================================================")
    
    if not CHECK_FILE_PATH.exists():
        print(f"[WARNING] No se encuentra el archivo de pruebas check: {CHECK_FILE_PATH}")
        return

    with open(CHECK_FILE_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    tests = []
    current_test = None
    for line in content.splitlines():
        if line.strip().startswith("-- TEST"):
            if current_test:
                tests.append(current_test)
            parts = line.split(":", 1)
            test_name = parts[1].strip() if len(parts) > 1 else line.strip()
            current_test = {
                'name': test_name,
                'expected_error': None,
                'sql_lines': []
            }
        elif line.strip().startswith("-- [EXPECTED_ERROR]"):
            if current_test:
                current_test['expected_error'] = line.replace("-- [EXPECTED_ERROR]", "").strip()
        elif current_test:
            current_test['sql_lines'].append(line)
    if current_test:
        tests.append(current_test)

    old_autocommit = conn.autocommit
    conn.autocommit = False
    
    total_tests = 0
    passed_tests = 0

    for test in tests:
        query = "\n".join(test['sql_lines']).strip()
        if not query:
            continue
            
        total_tests += 1
        test_name = test['name']
        expected_error = test['expected_error']
        
        try:
            with conn.cursor() as cur:
                cur.execute(query)
                print(f" [FALLIDO] {test_name}: Se insertó el registro sin disparar la restricción. (Esperado: {expected_error})")
                conn.rollback()
        except psycopg2.Error as err:
            conn.rollback()
            err_msg = str(err)
            if expected_error and expected_error.lower() in err_msg.lower():
                print(f" [PASADO]  {test_name} (Error capturado correctamente: {expected_error})")
                passed_tests += 1
            else:
                print(f" [FALLIDO] {test_name}: Falló con un error inesperado.\n   Detalle del error: {err_msg.strip()}")
                
    conn.autocommit = old_autocommit
    print(f"\nResultado global de restricciones: {passed_tests} de {total_tests} pasados.")
    print("=====================================================================")

def procesar_modelo_jcm2():
    print("=====================================================================")
    print("PROCESADOR DE MODELO DE DATOS Y REFINAMIENTO DE GEOMETRÍAS (jcm2)")
    print("=====================================================================")

    # 0. Consultar tablas existentes en el esquema jcm2
    tablas_existentes = set()
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        cur = conn.cursor()
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'jcm2';
        """)
        tablas_existentes = {row[0].lower() for row in cur.fetchall()}
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[WARNING] No se pudo consultar la lista de tablas existentes en jcm2: {e}")

    # Preguntar al usuario sobre la sobrescritura
    try:
        respuesta = input("¿Desea sobrescribir todas las tablas y reiniciar el esquema jcm2? (s/n) [s]: ").strip().lower()
        overwrite_all = respuesta not in ["n", "no"]
    except EOFError:
        overwrite_all = True

    core_tables = {'building', 'buildingpart', 'cadastralparcel', 'tramovial', 'portalpk', 'tramocurso', 'siose_pol', 'municipio'}
    if not overwrite_all:
        if core_tables.issubset(tablas_existentes):
            print("\n[NOTE] Saltando reconstrucción del esquema jcm2. Se utilizarán las tablas existentes.")
        else:
            print("\n[WARNING] Faltan tablas requeridas en el esquema jcm2. Se forzará la reconstrucción completa.")
            overwrite_all = True

    # 1. Read and format SQL processing file
    if not SQL_FILE_PATH.exists():
        print(f"[ERROR] No se encuentra el archivo SQL de procesamiento: {SQL_FILE_PATH}")
        sys.exit(1)

    print(f"Leyendo {SQL_FILE_PATH.name} y reemplazando marcadores de municipio (CODIGO: {CODIGO_MUNICIPIO}) y SRID (SRID: {SRID_PROYECTO})...")
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Dynamic replacement of the placeholders
    sql_content = sql_content.replace("{{CODIGO_MUNICIPIO}}", CODIGO_MUNICIPIO)
    sql_content = sql_content.replace("{{SRID_PROYECTO}}", str(SRID_PROYECTO))

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

        if overwrite_all:
            print("Ejecutando sentencias SQL para construir el esquema jcm2...")
            cur.execute(sql_content)
            print("[OK] Sentencias ejecutadas con éxito.")
        else:
            print("\n[NOTE] Saltando ejecución de sentencias SQL de reconstrucción de jcm2. Usando tablas existentes.")

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
                report_content = report_content.replace("{{SRID_PROYECTO}}", str(SRID_PROYECTO))
            
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
        
        # Ejecutar pruebas de restricciones CHECK
        try:
            ejecutar_pruebas_check(conn)
        except Exception as err_check:
            print(f"[WARNING] Falló la ejecución de pruebas check: {err_check}")

        conn.close()

        print("\n=====================================================================")
        print("PROCESAMIENTO DE ESQUEMA jcm2 COMPLETADO CON ÉXITO")
        print("=====================================================================")

        # Llamar a la creación condicional de vistas de calidad
        try:
            from crear_vistas_calidad_jcm2 import crear_vistas_calidad
            crear_vistas_calidad()
        except Exception as err_views:
            print(f"[WARNING] Falló la creación de vistas condicionales de calidad: {err_views}")

    except Exception as e:
        print(f"[ERROR] Falló la ejecución del procesamiento del modelo de datos: {e}")
        if conn:
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    procesar_modelo_jcm2()
