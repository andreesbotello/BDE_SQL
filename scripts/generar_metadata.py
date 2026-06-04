import json
import zipfile
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from osgeo import ogr, osr, gdal
from config import CODIGO_MUNICIPIO

# Habilitar excepciones en GDAL/OSR para capturar errores de forma limpia
gdal.UseExceptions()
osr.UseExceptions()

# Carpetas del proyecto
SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPTS_DIR.parent
DESCARGAS_DIR = ROOT_DIR / "descargas"

def extraer_info_gml(zip_path, gml_name):
    """Extrae metadatos, SRS, encoding, namespaces y cuenta elementos de un GML dentro de un ZIP.
    Usa iterparse para evitar cargar archivos gigantes en memoria.
    """
    srs_found = set()
    encoding = "UTF-8" # Por defecto para XML/GML
    namespaces = {}
    counts = {}
    
    with zipfile.ZipFile(zip_path, 'r') as z:
        # Detectar codificación leyendo la primera línea del archivo
        with z.open(gml_name, 'r') as f:
            first_line = f.readline().decode('utf-8', errors='ignore')
            m = re.search(r'encoding=["\']([^"\']+)["\']', first_line, re.IGNORECASE)
            if m:
                encoding = m.group(1)
        
        # Reset y lectura con iterparse para contar elementos e inspeccionar namespaces/SRS
        with z.open(gml_name, 'r') as f:
            events = ("start-ns", "start")
            context = ET.iterparse(f, events=events)
            
            for event, elem in context:
                if event == "start-ns":
                    prefix, uri = elem
                    namespaces[prefix] = uri
                elif event == "start":
                    # Buscar SRS en atributos
                    for attr, value in elem.attrib.items():
                        if attr.endswith("srsName"):
                            srs_found.add(value)
                    
                    # Contar elementos locales
                    tag = elem.tag
                    localname = tag.split('}')[-1] if '}' in tag else tag
                    counts[localname] = counts.get(localname, 0) + 1
                    
                    # Liberar memoria de elementos procesados para evitar sobrecarga
                    elem.clear()
                    
    return {
        "nombre_archivo": gml_name,
        "encoding": encoding,
        "namespaces": namespaces,
        "srs_detectados": list(srs_found),
        "conteo_elementos": counts
    }

def extraer_info_shp(zip_path, shp_name, zip_file):
    """Extrae metadatos, SRS, encoding y campos de un Shapefile dentro de un ZIP usando OGR."""
    # Construir la ruta virtual /vsizip/ para GDAL
    ogr_path = f"/vsizip/{zip_path.as_posix()}/{shp_name}"
    
    driver = ogr.GetDriverByName("ESRI Shapefile")
    ds = driver.Open(ogr_path, 0)
    if ds is None:
        raise Exception(f"No se pudo abrir el shapefile virtual en: {ogr_path}")
        
    layer = ds.GetLayer(0)
    layer_name = layer.GetName()
    feature_count = layer.GetFeatureCount()
    
    # Obtener el SRS
    srs = layer.GetSpatialRef()
    srs_detectado = "Desconocido"
    if srs is not None:
        srs_detectado = srs.GetName() or srs.GetAttrValue("AUTHORITY", 1) or srs.GetAttrValue("GEOGCS")
        
    # Obtener campos
    layer_defn = layer.GetLayerDefn()
    campos = []
    for i in range(layer_defn.GetFieldCount()):
        fld = layer_defn.GetFieldDefn(i)
        campos.append({
            "nombre": fld.GetName(),
            "tipo": fld.GetFieldTypeName(fld.GetType())
        })
        
    # Buscar archivo .cpg en el zip para leer la codificación especificada por el shapefile
    cpg_name = shp_name.rsplit('.', 1)[0] + ".cpg"
    encoding = "Desconocido (CPG no encontrado)"
    for name in zip_file.namelist():
        if name.lower() == cpg_name.lower():
            try:
                encoding = zip_file.read(name).decode('utf-8', errors='ignore').strip()
            except Exception:
                pass
            break
            
    # Intentar obtener un ejemplo de texto de campos comunes para validar los acentos/eñes
    ejemplos_valores = {}
    campos_a_inspeccionar = ["nombre", "nameunit", "tipovehicd", "calzadad", "fuented", "clased", "firmed", "tipo_curso"]
    
    layer.ResetReading()
    count = 0
    for feat in layer:
        for fld in campos:
            fld_name = fld["nombre"]
            if fld_name.lower() in campos_a_inspeccionar and fld_name not in ejemplos_valores:
                val = feat.GetField(fld_name)
                if val:
                    ejemplos_valores[fld_name] = str(val)
        count += 1
        if count >= 15: # Inspeccionar los primeros 15 features
            break
            
    ds = None # Cerrar dataset
    
    return {
        "nombre_archivo": shp_name,
        "capa_nombre": layer_name,
        "numero_entidades": feature_count,
        "srs_detectado": srs_detectado,
        "encoding_cpg": encoding,
        "campos": campos,
        "ejemplos_valores": ejemplos_valores
    }

def extraer_info_gpkg_zip(zip_path, gpkg_name_in_zip):
    """Extrae metadatos, capas y campos de un Geopackage dentro de un ZIP usando OGR."""
    ogr_path = f"/vsizip/{zip_path.as_posix()}/{gpkg_name_in_zip}"
    
    # Abrir usando gdal.OpenEx con la opción LIST_ALL_TABLES=YES para incluir tablas alfanuméricas
    ds = gdal.OpenEx(ogr_path, gdal.OF_VECTOR, open_options=["LIST_ALL_TABLES=YES"])
    if ds is None:
        raise Exception(f"No se pudo abrir el geopackage virtual en: {ogr_path}")
        
    capas_info = []
    
    # Comprobar si es un archivo de SIOSE para filtrar solo las tablas de interés del proyecto
    es_siose = "siose" in gpkg_name_in_zip.lower() or "siose" in zip_path.name.lower()
    capas_siose_interes = {"t_poligonos", "t_siose_codiige", "t_siose_hilucs"}

    for i in range(ds.GetLayerCount()):
        layer = ds.GetLayerByIndex(i)
        layer_name = layer.GetName()
        
        # Si es SIOSE, omitir capas no utilizadas para evitar sobrecarga y bloqueos en vsizip
        if es_siose and layer_name.lower() not in capas_siose_interes:
            continue
            
        feature_count = layer.GetFeatureCount()
        geom_type = layer.GetGeomType()
        
        srs = layer.GetSpatialRef()
        srs_detectado = "Desconocido"
        if srs is not None:
            srs_detectado = srs.GetName() or srs.GetAttrValue("AUTHORITY", 1) or srs.GetAttrValue("GEOGCS")
            
        layer_defn = layer.GetLayerDefn()
        campos = []
        for j in range(layer_defn.GetFieldCount()):
            fld = layer_defn.GetFieldDefn(j)
            campos.append({
                "nombre": fld.GetName(),
                "tipo": fld.GetFieldTypeName(fld.GetType())
            })
            
        capas_info.append({
            "capa_nombre": layer_name,
            "numero_entidades": feature_count,
            "srs_detectado": srs_detectado,
            "tipo_geometria": ogr.GeometryTypeToName(geom_type),
            "campos": campos
        })
        
    ds = None # Cerrar dataset
    
    return {
        "nombre_archivo": gpkg_name_in_zip,
        "capas": capas_info
    }

def analizar_zip(nombre_zip):
    zip_path = DESCARGAS_DIR / nombre_zip
    if not zip_path.exists():
        print(f"El archivo ZIP no existe: {zip_path}")
        return None
    
    # Validar si el JSON de metadatos ya existe y no está vacío (mínimo 100 bytes)
    nombre_json = zip_path.stem + "_metadata.json"
    json_path = DESCARGAS_DIR / nombre_json
    if json_path.exists() and json_path.stat().st_size > 100:
        print(f"El archivo de metadatos ya existe y es válido: {nombre_json}. Omitiendo análisis.")
        return None
    
    print(f"Analizando {nombre_zip}...")
    resultado = {
        "zip_nombre": nombre_zip,
        "zip_tamano_bytes": zip_path.stat().st_size,
        "archivos_internos": [],
        "analisis_gml": [],
        "analisis_shapefiles": [],
        "analisis_geopackages": []
    }
    
    with zipfile.ZipFile(zip_path, 'r') as z:
        for info in z.infolist():
            resultado["archivos_internos"].append({
                "nombre": info.filename,
                "tamano_comprimido_bytes": info.compress_size,
                "tamano_descomprimido_bytes": info.file_size
            })
            
            # Si es un GML, hacer análisis interno
            if info.filename.lower().endswith(".gml"):
                print(f"  -> Analizando GML interno: {info.filename}")
                try:
                    info_gml = extraer_info_gml(zip_path, info.filename)
                    resultado["analisis_gml"].append(info_gml)
                except Exception as e:
                    resultado["analisis_gml"].append({
                        "nombre_archivo": info.filename,
                        "error": str(e)
                    })
            
            # Si es un Shapefile (.shp), hacer análisis interno usando OGR
            elif info.filename.lower().endswith(".shp"):
                print(f"  -> Analizando Shapefile interno: {info.filename}")
                try:
                    info_shp = extraer_info_shp(zip_path, info.filename, z)
                    resultado["analisis_shapefiles"].append(info_shp)
                except Exception as e:
                    resultado["analisis_shapefiles"].append({
                        "nombre_archivo": info.filename,
                        "error": str(e)
                    })
                    
            # Si es un GeoPackage (.gpkg), hacer análisis interno usando OGR
            elif info.filename.lower().endswith(".gpkg"):
                print(f"  -> Analizando GeoPackage interno: {info.filename}")
                try:
                    info_gpkg = extraer_info_gpkg_zip(zip_path, info.filename)
                    resultado["analisis_geopackages"].append(info_gpkg)
                except Exception as e:
                    resultado["analisis_geopackages"].append({
                        "nombre_archivo": info.filename,
                        "error": str(e)
                    })
                    
    # Guardar los metadatos en un archivo JSON contiguo al ZIP
    nombre_json = zip_path.stem + "_metadata.json"
    json_path = DESCARGAS_DIR / nombre_json
    with open(json_path, 'w', encoding='utf-8') as jf:
        json.dump(resultado, jf, indent=4, ensure_ascii=False)
    
    print(f"Metadatos guardados en: {json_path}\n")
    return resultado

if __name__ == "__main__":
    print("=====================================================================")
    print("GENERADOR DE METADATOS DE ARCHIVOS DESCARGADOS")
    print("=====================================================================")
    
    # Buscar dinámicamente todos los archivos ZIP en la carpeta descargas/
    if not DESCARGAS_DIR.exists():
        print(f"[ERROR] No existe el directorio de descargas: {DESCARGAS_DIR}")
    else:
        archivos_zip = sorted([f.name for f in DESCARGAS_DIR.iterdir() if f.is_file() and f.suffix.lower() == ".zip"])
        if not archivos_zip:
            print(f"No se encontraron archivos ZIP en: {DESCARGAS_DIR}")
        else:
            print(f"Detectados {len(archivos_zip)} archivos ZIP para analizar.")
            for f_zip in archivos_zip:
                try:
                    analizar_zip(f_zip)
                except Exception as e:
                    print(f"[ERROR] Error al analizar {f_zip}: {e}")
    print("=====================================================================")
