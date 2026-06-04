# 1. IMPORTS
import os
import urllib.request
from pathlib import Path
from osgeo import ogr, osr, gdal
import shapely.wkt

# Configuración del proyecto y datos externos
from config import (
    CODIGO_MUNICIPIO,
    CODIGO_PROVINCIA,
    NOMBRE_MUNICIPIO,
    PROVINCIA,
    SRID_PROYECTO,
    PROVINCIA_DESCARGA,
    NIVEL_INFLUENCIA_HIDRO
)
from datos import CUENCAS_ZIP_MAP, PROVINCIA_A_SIOSE_MAP

# 2. PARÁMETROS Y VARIABLES
# Habilitar excepciones en GDAL/OSR para capturar errores de forma limpia
gdal.UseExceptions()
osr.UseExceptions()

# Directorios de trabajo
DESCARGAS_DIR = Path(__file__).resolve().parent.parent / "descargas"
GEOMETRIAS_DIR = Path(__file__).resolve().parent.parent / "geometrias_base"
MUNICIPIOS_GPKG = GEOMETRIAS_DIR / "MUNICIPIOS.gpkg"

# Mapear el nivel de influencia al sufijo de archivo de cuencas correspondiente
SUFIJO_MAP = {
    "servidumbre": "10m",
    "policia": "100m",
    "general": "500m"
}
sufijo_dist = SUFIJO_MAP.get(NIVEL_INFLUENCIA_HIDRO, "500m")


# 3. FUNCIONES
def descargar(url: str, nombre_fichero: str):
    """Descarga el archivo desde ``url`` y lo guarda en ``DESCARGAS_DIR`` con ``nombre_fichero``.
    Si el archivo ya existe, se omite la descarga.
    """
    ruta_destino = DESCARGAS_DIR / nombre_fichero
    if ruta_destino.exists():
        print(f"Archivo ya existe: {ruta_destino}")
        return ruta_destino
    print(f"Descargando {url} -> {ruta_destino}")
    try:
        urllib.request.urlretrieve(url, ruta_destino)
        print("Descarga completada.")
    except Exception as e:
        print(f"Error al descargar {url}: {e}")
    return ruta_destino

def obtener_geometria_municipio(gpkg_path, codigo_ine):
    """Abre MUNICIPIOS.gpkg y busca la geometría del municipio dinámicamente."""
    if not gpkg_path.exists():
        print(f"[ERROR] No existe el archivo de municipios en: {gpkg_path}")
        return None
        
    driver = ogr.GetDriverByName("GPKG")
    ds = driver.Open(str(gpkg_path), 0)
    if ds is None:
        print("[ERROR] No se pudo abrir MUNICIPIOS.gpkg")
        return None
        
    layer = ds.GetLayer(0)
    layer_defn = layer.GetLayerDefn()
    
    # Buscar cuál es la columna y valor del código del municipio
    columna_muni = None
    valor_muni = None
    es_numerico = False
    
    layer.ResetReading()
    for feat in layer:
        for i in range(layer_defn.GetFieldCount()):
            fld_name = layer_defn.GetFieldDefn(i).GetName()
            val = feat.GetField(fld_name)
            if val is not None:
                val_str = str(val).strip()
                # 1. Coincidencia exacta con el código INE (ej. "29051")
                # 2. Coincidencia con el estándar NATCODE de IGN (ej. "34172929051")
                # 3. Termina con el código INE (ej. "34172929051" termina en "29051")
                if (val_str == str(codigo_ine).strip() or 
                    val_str == f"3417{codigo_ine[:2]}{codigo_ine}" or 
                    (len(val_str) >= 5 and val_str.endswith(str(codigo_ine).strip()))):
                    columna_muni = fld_name
                    valor_muni = val
                    if isinstance(val, (int, float)):
                        es_numerico = True
                    break
        if columna_muni:
            break
            
    if not columna_muni:
        print(f"[ERROR] No se pudo identificar la columna de código municipal para: {codigo_ine}")
        return None
        
    print(f"Columna de código municipal identificada: '{columna_muni}' (Valor de búsqueda: {valor_muni})")
    
    # Buscar el municipio
    if es_numerico:
        layer.SetAttributeFilter(f"{columna_muni} = {valor_muni}")
    else:
        layer.SetAttributeFilter(f"{columna_muni} = '{valor_muni}'")
        
    layer.ResetReading()
    feat = layer.GetNextFeature()
        
    if feat is None:
        print(f"[ERROR] Municipio con código {codigo_ine} no encontrado en MUNICIPIOS.gpkg")
        return None
        
    geom = feat.GetGeometryRef().Clone()
    srs = layer.GetSpatialRef()
    if srs:
        srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        
    ds = None
    return geom, srs

def descargar_hidrografia():
    """Identifica las cuencas que intersectan con el municipio de estudio y descarga su hidrografía."""
    print(f"\n=== Iniciando Análisis e Intersección de Hidrografía (Influencia: {NIVEL_INFLUENCIA_HIDRO} -> {sufijo_dist}) ===")
    
    # 1. Obtener geometría y SRS del municipio de estudio
    res = obtener_geometria_municipio(MUNICIPIOS_GPKG, CODIGO_MUNICIPIO)
    if res is None:
        print("[ERROR] No se pudo obtener la geometría del municipio de estudio.")
        return
    muni_geom, muni_srs = res
    
    muni_shapely = shapely.wkt.loads(muni_geom.ExportToWkt())
    
    # 2. Buscar archivos GPKG de cuencas correspondientes a la influencia configurada
    cuencas_archivos = sorted(list(GEOMETRIAS_DIR.glob(f"*_{sufijo_dist}.gpkg")))
    if not cuencas_archivos:
        print(f"[ERROR] No se encontraron archivos de cuencas *_{sufijo_dist}.gpkg en {GEOMETRIAS_DIR}")
        return
        
    print(f"Se encontraron {len(cuencas_archivos)} archivos de cuencas para evaluar.")
    
    driver = ogr.GetDriverByName("GPKG")
    cuencas_a_descargar = []
    
    for c_path in cuencas_archivos:
        ds = driver.Open(str(c_path), 0)
        if ds is None:
            continue
            
        layer = ds.GetLayer(0)
        if layer is None or layer.GetFeatureCount() == 0:
            ds = None
            continue
            
        # Obtener primer feature para extraer atributos y geometría
        layer.ResetReading()
        feat = layer.GetNextFeature()
        if feat is None:
            ds = None
            continue
            
        codigo_cuenca = feat.GetField("codigo_cuenca")
        nombre_cuenca = feat.GetField("nombre_cuenca")
        geom_cuenca = feat.GetGeometryRef()
        
        # Reproyectar la geometría del municipio si los SRS difieren
        basin_srs = layer.GetSpatialRef()
        muni_geom_proj = muni_geom.Clone()
        if muni_srs is not None and basin_srs is not None:
            basin_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
            if not muni_srs.IsSame(basin_srs):
                transform = osr.CoordinateTransformation(muni_srs, basin_srs)
                muni_geom_proj.Transform(transform)
                
        # Intersección
        muni_shapely_proj = shapely.wkt.loads(muni_geom_proj.ExportToWkt())
        basin_shapely = shapely.wkt.loads(geom_cuenca.ExportToWkt())
        
        if muni_shapely_proj.intersects(basin_shapely):
            print(f"  [INTERSECTA] Municipio intersecta con la cuenca: {nombre_cuenca} ({codigo_cuenca})")
            cuencas_a_descargar.append((codigo_cuenca, nombre_cuenca))
            
        ds = None
        
    # 3. Descargar las cuencas intersectadas
    if not cuencas_a_descargar:
        print("[AVISO] El municipio no intersecta con ninguna cuenca. No se descargarán datos de hidrografía.")
        return
    
    print(f"\nSe procederá a descargar {len(cuencas_a_descargar)} cuenca(s) hidrográfica(s) detectada(s)...")
    for codigo, nombre in cuencas_a_descargar:
        zip_file = CUENCAS_ZIP_MAP.get(codigo)
        if not zip_file:
            print(f"  [ERROR] No se encuentra mapeado el archivo ZIP para el código de cuenca: {codigo} ({nombre})")
            continue
            
        url = f"http://ftpcdd.cnig.es/PUBLICACION_CNIG_DATOS_VARIOS/hidrografia/{zip_file}"
        print(f"  -> Descargando cuenca: {nombre} ({codigo})...")
        descargar(url, zip_file)

# 4. ACCIONES / EJECUCIONES
if __name__ == "__main__":
    print(f"Iniciando descargas para el municipio: {NOMBRE_MUNICIPIO} ({PROVINCIA}) con código: {CODIGO_MUNICIPIO}")
    
    # Crear carpeta de descargas
    DESCARGAS_DIR.mkdir(parents=True, exist_ok=True)
    
    # 4.1. Catastro Parcelas Catastrales en GML ATOM
    print("\n--- 4.1. Descargando Parcelas Catastrales ---")
    parcelas_url = (
        f"https://www.catastro.hacienda.gob.es/INSPIRE/CadastralParcels/{CODIGO_PROVINCIA}/"
        f"{CODIGO_MUNICIPIO}-{NOMBRE_MUNICIPIO.upper().replace(' ', '')}/"
        f"A.ES.SDGC.CP.{CODIGO_MUNICIPIO}.zip"
    )
    descargar(parcelas_url, f"Parcelas_{CODIGO_MUNICIPIO}.zip")
    
    # 4.2. Catastro Buildings en GML ATOM
    print("\n--- 4.2. Descargando Buildings Catastrales ---")
    buildings_url = (
        f"https://www.catastro.hacienda.gob.es/INSPIRE/Buildings/{CODIGO_PROVINCIA}/"
        f"{CODIGO_MUNICIPIO}-{NOMBRE_MUNICIPIO.upper().replace(' ', '')}/"
        f"A.ES.SDGC.BU.{CODIGO_MUNICIPIO}.zip"
    )
    descargar(buildings_url, f"Buildings_{CODIGO_MUNICIPIO}.zip")
    
    # 4.3. Redes de Transporte (CNIG - Shapefile Provincial)
    print("\n--- 4.3. Descargando Redes de Transporte ---")
    transport_url = f"http://ftpcdd.cnig.es/PUBLICACION_CNIG_DATOS_VARIOS/red_transporte/RT_{PROVINCIA_DESCARGA}_shp.zip"
    descargar(transport_url, f"RT_{PROVINCIA_DESCARGA}_shp.zip")
    
    # 4.4. Hidrografía por Intersección Espacial
    print("\n--- 4.4. Descargando Hidrografía por Intersección Espacial ---")
    descargar_hidrografia()
    
    # 4.5. Líneas límite (Líneas Base)
    print("\n--- 4.5. Descargando Líneas Límite (Líneas Base) ---")
    lineas_base_url = "http://ftpcdd.cnig.es/PUBLICACION_CNIG_DATOS_VARIOS/lineas_limite/lineas_limite.zip"
    descargar(lineas_base_url, "lineas_limite.zip")
    
    # 4.6. SIOSE geopackage
    print("\n--- 4.6. Descargando SIOSE Geopackage ---")
    siose_region = PROVINCIA_A_SIOSE_MAP.get(CODIGO_PROVINCIA, "Andalucia")
    siose_zip = f"SIOSE_{siose_region}_2014_GPKG.zip"
    siose_url = f"http://ftpcdd.cnig.es/SIOSE/SIOSE_2014/{siose_zip}"
    descargar(siose_url, siose_zip)
    
    print("\n=== Descargas completadas. ===")