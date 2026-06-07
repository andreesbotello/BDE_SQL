import os
import sys
from pathlib import Path
import psycopg2

# Configurar path para importar config.py
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.append(str(SCRIPTS_DIR))

from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, SRID_PROYECTO

SQL_FILE_PATH = SCRIPTS_DIR / "procesar_jcm3.sql"
CHECK_FILE_PATH = SCRIPTS_DIR / "validar_check_jcm3.sql"

def ejecutar_pruebas_check(conn):
    print("\n=====================================================================")
    print("EJECUTANDO PRUEBAS DE RESTRICCIONES CHECK (VALIDAR REGLAS DE NEGOCIO JCM3)")
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
    print(f"\nResultado global de restricciones JCM3: {passed_tests} de {total_tests} pasados.")
    print("=====================================================================")

def procesar_analisis_jcm3():
    print("=====================================================================")
    print("PROCESADOR DE ANÁLISIS ESPACIAL Y REGLAS TOPOLÓGICAS (jcm3)")
    print("=====================================================================")

    # 1. Leer archivo SQL de procesamiento
    if not SQL_FILE_PATH.exists():
        print(f"[ERROR] No se encuentra el archivo SQL de análisis: {SQL_FILE_PATH}")
        sys.exit(1)

    print(f"Leyendo {SQL_FILE_PATH.name} y reemplazando marcador SRID (SRID: {SRID_PROYECTO})...")
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        sql_content = f.read()

    sql_content = sql_content.replace("{{SRID_PROYECTO}}", str(SRID_PROYECTO))

    # 2. Conectar a PostGIS
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

        print("Ejecutando sentencias SQL para construir el esquema jcm3 y disparadores...")
        cur.execute(sql_content)
        print("[OK] Sentencias ejecutadas con éxito en la base de datos.")

        # 3. Mostrar Diagnóstico Inicial (Pre-Corrección)
        print("\n" + "=" * 80)
        print("DIAGNÓSTICO INICIAL DE INCONSISTENCIAS (Estado Pre-Corrección en JCM2)")
        print("=" * 80)
        
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_inspire_edificios;")
        inspire_b = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_inspire_viales;")
        inspire_v = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_solapes_edificios;")
        solapes_b = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_solapes_viales;")
        solapes_v = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_cruces_sin_nodo;")
        cruces_sn = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_buildingpart_sin_building;")
        sin_building = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM jcm3.view_diag_buildingpart_huerfano;")
        huerfanos_bp = cur.fetchone()[0]
        
        print(f"  - Edificios con gml_id nulo/duplicado (UML INSPIRE) : {inspire_b}")
        print(f"  - Tramos viales con id_tramo nulo/duplicado (INSPIRE): {inspire_v}")
        print(f"  - Solapes espaciales entre edificios                 : {solapes_b}")
        print(f"  - Intersecciones / solapes vial - edificio          : {solapes_v}")
        print(f"  - Cruces viales sin nodo topológico                 : {cruces_sn}")
        print(f"  - BuildingPart no contenidos en su Building padre    : {sin_building}")
        print(f"  - BuildingPart huérfanos (sin Building padre)        : {huerfanos_bp}")

        # 4. Generar y reportar reporte de correcciones topológicas (jcm3)
        print("\n" + "=" * 80)
        print("REPORTE DE CORRECCIONES TOPOLÓGICAS AUTOMATIZADAS (jcm3)")
        print("=" * 80)
        
        reporte_path = SCRIPTS_DIR / "reporte_jcm3.sql"
        if reporte_path.exists():
            with open(reporte_path, "r", encoding="utf-8") as f:
                reporte_sql = f.read()
            reporte_sql = reporte_sql.replace("{{SRID_PROYECTO}}", str(SRID_PROYECTO))
            cur.execute(reporte_sql)
            rows = cur.fetchall()
            for r in rows:
                seccion = r[0]
                detalle = r[1]
                cantidad = int(r[2]) if r[2] is not None else 0
                if detalle == '' and cantidad == 0:
                    print(f"\n{seccion}")
                    print("-" * len(seccion))
                else:
                    print(f"  {seccion.ljust(58)}: {cantidad}")
        else:
            print("[WARNING] No se encontró el archivo de reporte: reporte_jcm3.sql")

        # 4.5. Tabla resumen de trazabilidad de calidad
        print("\n" + "=" * 80)
        print("TABLA RESUMEN DE TRAZABILIDAD Y CALIDAD EN JCM3 (Criterios INSPIRE)")
        print("=" * 80)
        print(f"  {'CAPA'.ljust(18)} | {'TIPO DE ERROR'.ljust(35)} | {'CORREGIDO'.ljust(15)} | {'TOTAL'.rjust(6)}")
        print(f"  {'-'*18}-+-{'-'*35}-+-{'-'*15}-+-{'-'*6}")
        
        cur.execute("SELECT capa, tipo_error, corregido, total_elementos FROM jcm3.view_reporte_resumen_calidad ORDER BY capa, tipo_error, corregido;")
        for row in cur.fetchall():
            capa = row[0]
            tipo_error = row[1]
            corregido = row[2]
            total = row[3]
            print(f"  {capa.ljust(18)} | {tipo_error.ljust(35)} | {corregido.ljust(15)} | {str(total).rjust(6)}")

        # 4.6. Tabla resumen comparativa JCM2 vs JCM3
        print("\n" + "=" * 80)
        print("TABLA COMPARATIVA DE CALIDAD GEOMÉTRICA (ESTADO JCM2 VS ESTADO JCM3)")
        print("=" * 80)
        print(f"  {'CONTROL DE CALIDAD'.ljust(35)} | {'INCONSISTENCIAS JCM2'.rjust(20)} | {'INCONSISTENCIAS JCM3'.rjust(20)}")
        print(f"  {'-'*35}-+-{'-'*20}-+-{'-'*20}")
        
        cur.execute("SELECT control_calidad, inconsistencias_jcm2, inconsistencias_jcm3 FROM jcm3.view_resumen_calidad_antes_despues;")
        for row in cur.fetchall():
            ctrl = row[0]
            antes = row[1]
            despues = row[2]
            print(f"  {ctrl.ljust(35)} | {str(antes).rjust(20)} | {str(despues).rjust(20)}")

        # 5. Generar y reportar resultados analíticos
        print("\n" + "=" * 80)
        print("REPORTE DE RESULTADOS DE CONSULTAS ESPACIALES CORREGIDAS (SECCIÓN 8 Y 9)")
        print("=" * 80)

        # 8.1.1
        cur.execute("SELECT total_parcelas_con_edificios FROM jcm3.view_q8_1_1;")
        q8_1_1 = cur.fetchone()[0]
        print(f"Q8.1.1. Parcelas catastrales con algún edificio en su interior: {q8_1_1}")

        # 8.1.2
        cur.execute("SELECT total_parcelas_vacias FROM jcm3.view_q8_1_2;")
        q8_1_2 = cur.fetchone()[0]
        print(f"Q8.1.2. Parcelas catastrales vacías (sin ningún edificio): {q8_1_2}")

        # 8.1.3
        cur.execute("SELECT gml_id, num_edificios FROM jcm3.view_q8_1_3;")
        res_8_1_3 = cur.fetchone()
        if res_8_1_3:
            print(f"Q8.1.3. Parcela con más edificios dentro: Ref. {res_8_1_3[0]} ({res_8_1_3[1]} edificios)")
        else:
            print("Q8.1.3. Parcela con más edificios dentro: No se encontraron registros.")

        # 8.2
        cur.execute("SELECT total_edificios_aislados FROM jcm3.view_q8_2;")
        q8_2 = cur.fetchone()[0]
        print(f"Q8.2.   Edificios aislados (sin vecinos en un radio de 100m): {q8_2}")

        # 8.3
        print("\nQ8.3.   Área total de edificios por tipo de suelo SIOSE (Top 5):")
        cur.execute("SELECT codiige, suelo_descripcion, area_edificada_m2 FROM jcm3.view_q8_3;")
        for row in cur.fetchall():
            print(f"        - Cód: {str(row[0]).ljust(3)} | {row[1].ljust(35)} : {row[2]:,} m2")

        # 8.4
        print("\nQ8.4.   Edificios con mayor volumen estimado de sótanos (Top 5):")
        cur.execute("SELECT building_gml_id, volumen_sotanos_m3 FROM jcm3.view_q8_4;")
        for row in cur.fetchall():
            print(f"        - Edificio: {row[0]} : {row[1]:,} m3")

        # 8.5.1 (Propuesta estudiante: riesgo inundación)
        cur.execute("SELECT total_edificios_riesgo_inundacion FROM jcm3.view_q8_5_1;")
        q8_5_1 = cur.fetchone()[0]
        print(f"\nQ8.5.1. Edificios a menos de 50 metros de un cauce fluvial (inundación): {q8_5_1}")

        # 8.5.2 (Propuesta estudiante: densidad urbana SIOSE)
        print("Q8.5.2. Densidad edificada por polígono SIOSE urbano (Top 5 más densos):")
        cur.execute("SELECT siose_gid, codiige, suelo_descripcion, porcentaje_edificado FROM jcm3.view_q8_5_2;")
        for row in cur.fetchall():
            print(f"        - Polígono ID: {str(row[0]).ljust(5)} | Cód SIOSE: {row[1]} ({row[2]}) : {row[3]}% edificado")

        # Reporte de entidades que requieren corrección manual
        print("\n" + "=" * 80)
        print("RESUMEN DE ENTIDADES QUE REQUIEREN CORRECCIÓN MANUAL (QA/QC EN JCM3)")
        print("=" * 80)
        
        cur.execute("SELECT count(*) FROM jcm3.building WHERE requiere_edicion_manual;")
        manual_buildings = cur.fetchone()[0]
        print(f"Edificios (building) que requieren edición manual: {manual_buildings}")
        if manual_buildings > 0:
            cur.execute("SELECT gml_id, motivo_inconsistencia FROM jcm3.building WHERE requiere_edicion_manual LIMIT 5;")
            for row in cur.fetchall():
                print(f"  - Edificio ID: {row[0]} | Motivo: {row[1]}")
                
        cur.execute("SELECT count(*) FROM jcm3.tramovial WHERE requiere_edicion_manual;")
        manual_roads = cur.fetchone()[0]
        print(f"Tramos viales (tramovial) que requieren edición manual: {manual_roads}")
        if manual_roads > 0:
            cur.execute("SELECT id_tramo, motivo_inconsistencia FROM jcm3.tramovial WHERE requiere_edicion_manual LIMIT 5;")
            for row in cur.fetchall():
                motivo = row[1] if row[1] else "Inconsistencia no especificada"
                print(f"  - Vial ID: {row[0]} | Motivo: {motivo}")
        print("=" * 80)

        # 9 (Localización Óptima)
        print("\n" + "=" * 80)
        print("RESULTADOS DEL ANÁLISIS DE LOCALIZACIÓN ÓPTIMA MULTICRITERIO (SECCIÓN 9)")
        print("=" * 80)
        cur.execute("SELECT count(*) FROM jcm3.view_parcelas_candidatas_centro;")
        num_candidatas = cur.fetchone()[0]
        print(f"Se han identificado {num_candidatas} parcelas catastrales óptimas para equipamientos públicos.")
        
        if num_candidatas > 0:
            print("\nMuestra de las parcelas óptimas candidatas (Top 5 por área):")
            cur.execute("SELECT parcela_gml_id, parcela_localid, area_parcela_m2 FROM jcm3.view_parcelas_candidatas_centro ORDER BY area_parcela_m2 DESC LIMIT 5;")
            for row in cur.fetchall():
                print(f"  - Ref Catastral: {row[0]} | LocalID: {row[1].ljust(14)} | Superficie: {row[2]:,} m2")
        else:
            print("No se encontraron parcelas que cumplan con la totalidad de los criterios establecidos.")

        print("=" * 80)

        # 4. Validación en vivo de Triggers (Sección 10)
        print("\n" + "=" * 80)
        print("VALIDACIÓN EN VIVO DE DISPARADORES (TRIGGERS)")
        print("=" * 80)

        # A. Verificar trigger de cálculo automático de área
        print("Probando Trigger de Área Automática (jcm2):")
        cur.execute("SELECT gml_id, ST_Area(geom) as area_geom, superficie_m2 FROM jcm2.building LIMIT 1;")
        row_area = cur.fetchone()
        if row_area:
            print(f"  - Edificio Ref: {row_area[0]}")
            print(f"  - Área por función ST_Area: {row_area[1]:.4f} m2")
            print(f"  - Área en columna superficie_m2: {row_area[2]:.4f} m2")
            if abs(row_area[1] - row_area[2]) < 0.0001:
                print("  [OK] El disparador calculó y guardó correctamente la superficie en la columna.")
            else:
                print("  [ALERTA] Hay discrepancia entre la columna autocalculada y ST_Area.")
        else:
            print("  No hay edificios en jcm2.building para realizar la prueba.")

        # B. Verificar trigger de prevención de solapes
        print("\nProbando Trigger de Solapes (jcm2 - Simulación):")
        cur.execute("SELECT geom FROM jcm2.building LIMIT 1;")
        row_geom = cur.fetchone()
        if row_geom:
            geom_wkt = row_geom[0]
            
            insert_sql = """
                INSERT INTO jcm2.building (gml_id, currentuse, geom)
                VALUES ('TEST_GML_ID_SOLAPADO', 'residential', %s);
            """
            
            conn.autocommit = False
            try:
                cur.execute(insert_sql, (geom_wkt,))
                conn.commit()
                print("  [ALERTA] ¡La inserción de un edificio solapado fue permitida! El trigger falló.")
            except psycopg2.Error as e:
                conn.rollback()
                print("  [OK] El servidor de base de datos rechazó la inserción exitosamente.")
                print(f"  Mensaje de Error de PostGIS: {e.pgerror.strip().splitlines()[0]}")
            finally:
                conn.autocommit = True
        else:
            print("  No hay edificios en jcm2.building para realizar la prueba.")

        # C. Verificar trigger de corrección manual en JCM3
        print("\nProbando Trigger de Corrección Manual (jcm3 - Simulación):")
        cur.execute("SELECT gid, geom FROM jcm3.building WHERE corregido = 'no' LIMIT 1;")
        row_manual = cur.fetchone()
        if row_manual:
            b_gid = row_manual[0]
            # Mover temporalmente su geometría 100km al noreste para resolver el solape
            move_sql = "UPDATE jcm3.building SET geom = ST_Translate(geom, 100000, 100000) WHERE gid = %s RETURNING corregido;"
            conn.autocommit = False
            try:
                cur.execute(move_sql, (b_gid,))
                new_corr = cur.fetchone()[0]
                print(f"  - Edificio GID {b_gid} modificado geométricamente.")
                print(f"  - Nuevo estado del campo 'corregido': {new_corr}")
                if new_corr == 'manual':
                    print("  [OK] El disparador detectó la edición manual y resolvió el estado de calidad.")
                else:
                    print("  [ALERTA] El campo 'corregido' no se actualizó a 'manual'.")
                conn.rollback() # No guardar cambios
            except Exception as e_m:
                conn.rollback()
                print(f"  [ALERTA] Falló la simulación de edición manual: {e_m}")
            finally:
                conn.autocommit = True
        else:
            print("  No hay edificios con errores pendientes (corregido = 'no') para realizar la prueba de edición manual.")

        # Ejecutar suite de pruebas unitarias CHECK
        ejecutar_pruebas_check(conn)

        cur.close()
        conn.close()

        print("\n=====================================================================")
        print("ANÁLISIS DE ESQUEMA jcm3 COMPLETADO CON ÉXITO")
        print("=====================================================================")

    except Exception as e:
        print(f"[ERROR] Falló la ejecución del análisis del esquema jcm3: {e}")
        if conn:
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    procesar_analisis_jcm3()
