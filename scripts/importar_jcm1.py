import os
import sys
import zipfile
from pathlib import Path
import psycopg2
from osgeo import gdal
from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, CODIGO_MUNICIPIO, PROVINCIA_DESCARGA

# Habilitar excepciones en GDAL para capturar errores de forma limpia
gdal.UseExceptions()

# Carpetas del proyecto
SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPTS_DIR.parent
DESCARGAS_DIR = ROOT_DIR / "descargas"
TEMP_DIR = ROOT_DIR / "temp"

def buscar_archivo_en_zip(zip_path, patron):
    """Busca un archivo dentro de un ZIP que contenga el patrón en su nombre (sin distinguir mayúsculas/minúsculas)."""
    with zipfile.ZipFile(zip_path, 'r') as z:
        for name in z.namelist():
            if patron.lower() in name.lower() and (name.lower().endswith(".shp") or name.lower().endswith(".gml") or name.lower().endswith(".gpkg")):
                return name
    return None

def importar_capas():
    # Establecer la contraseña en la variable de entorno para la conexión de GDAL
    if DB_PASSWORD:
        os.environ["PGPASSWORD"] = DB_PASSWORD
        
    conn_string = f"PG:host={DB_HOST} port={DB_PORT} user={DB_USER} dbname={DB_NAME}"

    # 0. Consultar tablas existentes en el esquema jcm1
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
            WHERE table_schema = 'jcm1';
        """)
        tablas_existentes = {row[0].lower() for row in cur.fetchall()}
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[WARNING] No se pudo consultar la lista de tablas existentes: {e}")

    # Preguntar al usuario sobre la sobrescritura
    respuesta = input("¿Desea sobrescribir todas las tablas y reiniciar el esquema jcm1? (s/n) [s]: ").strip().lower()
    overwrite_all = respuesta not in ["n", "no"]

    # Ejecutar el SQL de limpieza si se desea sobrescribir todo
    if overwrite_all:
        sql_path = SCRIPTS_DIR / "importar_jcm1.sql"
        if sql_path.exists():
            print(f"Ejecutando sentencias de limpieza desde {sql_path.name}...")
            try:
                conn = psycopg2.connect(
                    host=DB_HOST,
                    port=DB_PORT,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    database=DB_NAME
                )
                conn.autocommit = True
                cur = conn.cursor()
                with open(sql_path, "r", encoding="utf-8") as f:
                    sql_queries = f.read()
                cur.execute(sql_queries)
                cur.close()
                conn.close()
                print("[OK] Esquema jcm1 preparado y limpiado con éxito.")
            except Exception as e:
                print(f"[ERROR] No se pudo ejecutar el script de limpieza SQL: {e}")
                sys.exit(1)
        else:
            print(f"[WARNING] No se encontró el archivo de limpieza: {sql_path}")
    else:
        print("[NOTE] Saltando limpieza de esquema. Solo se importarán las tablas faltantes.")

    print("=== Iniciando Importación de Capas Requeridas en Esquema 'jcm1' ===")
    
    # Construir dinámicamente la lista de capas a importar basadas únicamente en las exigencias del proyecto
    capas_a_importar = []
    
    # 1. Catastro CP (Cadastral Parcels) -> cadastralparcel
    cp_zip = f"Parcelas_{CODIGO_MUNICIPIO}.zip"
    if (DESCARGAS_DIR / cp_zip).exists():
        gml_file = buscar_archivo_en_zip(DESCARGAS_DIR / cp_zip, "cadastralparcel.gml")
        if gml_file:
            capas_a_importar.append((cp_zip, gml_file, "cadastralparcel", None))
            
    # 2. Catastro BU (Buildings) -> building, buildingpart
    bu_zip = f"Buildings_{CODIGO_MUNICIPIO}.zip"
    if (DESCARGAS_DIR / bu_zip).exists():
        gml_b = buscar_archivo_en_zip(DESCARGAS_DIR / bu_zip, "building.gml")
        if gml_b:
            capas_a_importar.append((bu_zip, gml_b, "building", None))
        gml_bp = buscar_archivo_en_zip(DESCARGAS_DIR / bu_zip, "buildingpart.gml")
        if gml_bp:
            capas_a_importar.append((bu_zip, gml_bp, "buildingpart", None))
            
    # 3. Red de Transporte -> tramovial, portalpk
    rt_zip = f"RT_{PROVINCIA_DESCARGA}_shp.zip"
    if (DESCARGAS_DIR / rt_zip).exists():
        shp_tv = buscar_archivo_en_zip(DESCARGAS_DIR / rt_zip, "rt_tramo_vial")
        if shp_tv:
            capas_a_importar.append((rt_zip, shp_tv, "tramovial", None))
        shp_pk = buscar_archivo_en_zip(DESCARGAS_DIR / rt_zip, "rt_portalpk_p")
        if shp_pk:
            capas_a_importar.append((rt_zip, shp_pk, "portalpk", None))
            
    # 4. Red de Hidrografía -> tramocurso
    zip_hidro = None
    for f in DESCARGAS_DIR.glob("DH_V0_*.ZIP"):
        zip_hidro = f.name
        break
    if not zip_hidro:
        for f in DESCARGAS_DIR.glob("DH_V0_*.zip"):
            zip_hidro = f.name
            break
            
    if zip_hidro:
        shp_hc = buscar_archivo_en_zip(DESCARGAS_DIR / zip_hidro, "hi_tramocurso_l")
        if shp_hc:
            capas_a_importar.append((zip_hidro, shp_hc, "tramocurso", None))
            
    # 5. Líneas Municipales (Límites Base) -> ttmm
    ll_zip = "lineas_limite.zip"
    if (DESCARGAS_DIR / ll_zip).exists():
        shp_ll = buscar_archivo_en_zip(DESCARGAS_DIR / ll_zip, "recintos_municipales_inspire_peninbal_etrs89")
        if shp_ll:
            capas_a_importar.append((ll_zip, shp_ll, "ttmm", None))
            
    # 6. SIOSE -> siose_pol y tablas alfanuméricas
    siose_tables = ["siose_pol", "siose_codiige", "siose_hilucs"]
    necesita_siose = overwrite_all or any(t not in tablas_existentes for t in siose_tables)

    if necesita_siose:
        gpkg_siose = None
        # Buscar el gpkg ya descomprimido en descargas
        for f in DESCARGAS_DIR.glob("*.gpkg"):
            if "SIOSE" in f.name.upper():
                gpkg_siose = f.name
                break
                
        if not gpkg_siose:
            gpkg_siose = "SIOSE_Andalucia_2014.gpkg"
            gpkg_dest = DESCARGAS_DIR / gpkg_siose
            print("\n" + "="*80, flush=True)
            print("AVISO: Se asume que debió haber descomprimido el archivo ZIP de SIOSE previamente.", flush=True)
            print(f"No se encontró el GeoPackage '{gpkg_siose}' en la carpeta de descargas: {DESCARGAS_DIR}", flush=True)
            print("="*80 + "\n", flush=True)
            
            while not gpkg_dest.exists():
                input(f"Archivo {gpkg_siose} no encontrado. Por favor, descomprímalo para continuar y presione ENTER...")
            print("[OK] GeoPackage de SIOSE detectado.", flush=True)

        capas_a_importar.append((None, gpkg_siose, "siose_pol", ["T_POLIGONOS"]))
        capas_a_importar.append((None, gpkg_siose, "siose_codiige", ["TC_SIOSE_CODIIGE"]))
        capas_a_importar.append((None, gpkg_siose, "siose_hilucs", ["TC_SIOSE_HILUCS"]))

    # Realizar la importación de cada capa
    for zip_file, inner_file, table_name, layers in capas_a_importar:
        if not overwrite_all and table_name in tablas_existentes:
            print(f"\n[SKIP] La tabla jcm1.{table_name} ya existe. Saltando importación...")
            continue
        if zip_file is not None:
            zip_path = DESCARGAS_DIR / zip_file
            if not zip_path.exists():
                print(f"[ERROR] No se encuentra el archivo ZIP: {zip_path}")
                continue
            gdal_src_path = f"/vsizip/{zip_path.as_posix()}/{inner_file}"
        else:
            # Archivo descomprimido directo
            direct_path = DESCARGAS_DIR / inner_file
            if not direct_path.exists():
                print(f"[ERROR] No se encuentra el archivo: {direct_path}")
                continue
            gdal_src_path = direct_path.as_posix()
        
        print(f"\nImportando: {inner_file} -> jcm1.{table_name}...")
        
        try:
            # Abrir el dataset de origen de forma explícita
            open_opts = []
            if inner_file.lower().endswith(".gpkg") or table_name.startswith("siose_"):
                open_opts = ["LIST_ALL_TABLES=YES"]
                
            src_ds = gdal.OpenEx(gdal_src_path, gdal.OF_VECTOR, open_options=open_opts)
            if src_ds is None:
                print(f"[ERROR] No se pudo abrir el archivo de origen: {gdal_src_path}")
                continue

            # Configurar opciones de VectorTranslate (ogr2ogr)
            creation_options = ["SCHEMA=jcm1", "PRECISION=NO"]
            if table_name not in ["siose_codiige", "siose_hilucs"]:
                creation_options.append("GEOMETRY_NAME=geom")
                
            vt_opts = {
                "format": "PostgreSQL",
                "layerName": table_name,
                "layerCreationOptions": creation_options,
                "accessMode": "overwrite"
            }
            if table_name not in ["siose_codiige", "siose_hilucs"]:
                vt_opts["geometryType"] = "PROMOTE_TO_MULTI"

            if layers:
                vt_opts["layers"] = layers
                
            options = gdal.VectorTranslateOptions(**vt_opts)
            
            # Ejecutar la traducción del vector utilizando el dataset ya abierto
            ds = gdal.VectorTranslate(
                destNameOrDestDS=conn_string,
                srcDS=src_ds,
                options=options
            )
            # Cerrar datasets
            ds = None
            src_ds = None
            print(f"[OK] Importación de {table_name} completada exitosamente.")
            
        except Exception as e:
            print(f"[ERROR] Error al importar {table_name}: {e}")

if __name__ == "__main__":
    importar_capas()