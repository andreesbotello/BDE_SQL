# Análisis Inicial de Metadatos y Estructura del Proyecto

**Municipio de Estudio:** Estepona (Málaga) - Código INE: 29051  
**SRS de Proyecto:** EPSG:25830 (ETRS89 / UTM Huso 30N)

Este documento detalla la estructura física, los sistemas de referencia (SRS), las codificaciones (encoding), los recuentos de objetos y los campos de interés de todos los conjuntos de datos descargados para la automatización del proyecto.

---

## 1. Catastro: Parcelas Catastrales (`Parcelas_29051.zip`)
* **Tamaño del ZIP:** 6.50 MB (6,814,840 bytes)
* **Archivos clave analizados:**
  * `A.ES.SDGC.CP.29051.cadastralparcel.gml` (GML: 41.86 MB)
  * `A.ES.SDGC.CP.29051.cadastralzoning.gml` (GML: 8.52 MB)
* **Codificación (Encoding):** `UTF-8`
* **SRS Original:** `http://www.opengis.net/def/crs/EPSG/0/25830` (EPSG:25830)
* **Namespaces:** `xmlns:cp="http://inspire.ec.europa.eu/schemas/cp/4.0"`
* **Recuentos y Objetos de Interés:**
  * **Parcelas Catastrales (`cp:CadastralParcel`):** 16,985 objetos (se importa como `cadastralparcel`).
  * **Zonificación Catastral (`cp:CadastralZoning`):** 1,594 objetos.
* **Campos clave de interés:**
  * `gml:id` -> Identificador GML (mapeado a `gml_id`).
  * `cp:areaValue` -> Superficie de la parcela (mapeado a `areavalue`).
  * `cp:localId` -> Identificador alfanumérico local (mapeado a `localid`).

---

## 2. Catastro: Edificios (`Buildings_29051.zip`)
* **Tamaño del ZIP:** 9.37 MB (9,821,770 bytes)
* **Archivos clave analizados:**
  * `A.ES.SDGC.BU.29051.building.gml` (GML: 55.68 MB)
  * `A.ES.SDGC.BU.29051.buildingpart.gml` (GML: 143.28 MB)
* **Codificación (Encoding):** `ISO-8859-1` (Requiere configuración explícita al importar para evitar caracteres corruptos en nombres o usos).
* **SRS Original:** `urn:ogc:def:crs:EPSG::25830` (EPSG:25830)
* **Namespaces:** `xmlns:bu-base="http://inspire.jrc.ec.europa.eu/schemas/bu-base/3.0"`
* **Recuentos y Objetos de Interés:**
  * **Edificios (`bu:Building`):** 11,758 objetos (se importa como `building`).
  * **Partes de Edificios (`bu:BuildingPart`):** 58,908 objetos (se importa como `buildingpart`).
* **Campos clave de interés:**
  * `currentUse` -> Uso actual del edificio (ej. residential, commercial).
  * `numberOfBuildingUnits` -> Número de viviendas/locales.
  * `numberOfFloorsAboveGround` -> Plantas sobre rasante.
  * `numberOfFloorsBelowGround` -> Plantas bajo rasante.

---

## 3. Red de Transporte (`RT_MALAGA_shp.zip`)
* **Tamaño del ZIP:** 71.13 MB (71,127,362 bytes)
* **Formato:** Shapefile (de ámbito provincial - Málaga)
* **Codificación (Encoding):** `ISO-8859-1` (declarado en los archivos `.cpg`).
* **SRS Original:** ETRS89 (Geodésicas, EPSG:4258)
* **Recuentos y Objetos de Interés:**
  * **Tramos Viales (`rt_tramo_vial.shp`):** 250,707 entidades en toda la provincia (se filtra e importa como `tramovial`).
  * **Portales y PKs (`rt_portalpk_p.shp`):** 385,381 entidades en toda la provincia (se filtra e importa como `portalpk`).
* **Campos clave de interés:**
  * En `rt_tramo_vial`: `id_tramo`, `id_vial`, `clased` (Clase de tramo), `nombre` (Nombre de la calle), `firmed` (Tipo de firme).
  * En `rt_portalpk`: `id_porpk`, `id_tramo`, `id_vial`, `numero` (Número de portal).

---

## 4. Red de Hidrografía (`DH_V0_ES060_Cuencas_Mediterraneas_Andaluzas.ZIP`)
* **Tamaño del ZIP:** 228.54 MB (228,543,509 bytes)
* **Formato:** Shapefile (de ámbito de demarcación hidrográfica - Cuencas Mediterráneas Andaluzas)
* **Codificación (Encoding):** `ISO-8859-1` (UTF-8 compatible al decodificar).
* **SRS Original:** ETRS89 (Geodésicas, EPSG:4258)
* **Recuentos y Objetos de Interés:**
  * **Tramos de Cursos de Agua (`hi_tramocurso_l_ES060.shp`):** 41,477 entidades en toda la cuenca (se filtra por intersección e importa como `tramocurso`).
* **Campos clave de interés:**
  * `id_curso` -> Identificador único del curso de agua.
  * `nombre` -> Nombre del río o arroyo.
  * `tipo_curso` -> Tipo de curso (ej. efímero, intermitente, permanente).

---

## 5. Líneas Municipales: Límites Base (`lineas_limite.zip`)
* **Tamaño del ZIP:** 143.96 MB (143,963,710 bytes)
* **Formato:** Shapefile (ámbito nacional)
* **Codificación (Encoding):** `UTF-8`
* **SRS Original:** ETRS89 (Geodésicas, EPSG:4258)
* **Recuentos y Objetos de Interés:**
  * **Recintos Municipales (`SHP_ETRS89/recintos_municipales_inspire_peninbal_etrs89/recintos_municipales_inspire_peninbal_etrs89.shp`):** 8,132 municipios de España (se importa como `ttmm`).
* **Campos clave de interés:**
  * `NATCODE` -> Código de municipio (usado para identificar a Estepona con código `29051`).
  * `NAMEUNIT` -> Nombre oficial del municipio (`Estepona`).
  * `INSPIREID` -> Identificador oficial para INSPIRE.

---

## 6. Ocupación del Suelo: SIOSE (`SIOSE_Andalucia_2014_GPKG.zip`)
* **Tamaño del ZIP:** 922.86 MB (922,859,702 bytes)
* **Formato:** GeoPackage (ámbito de Comunidad Autónoma - Andalucía)
* **Codificación (Encoding):** `UTF-8` (nativo de GeoPackage)
* **SRS Original:** ETRS89 / UTM zone 30N (EPSG:25830)
* **Recuentos y Objetos de Interés:**
  * **Polígonos de Ocupación (`T_POLIGONOS`):** 766,791 entidades (se filtra e importa como `siose_pol`).
  * **Clasificación de Cobertura (`t_siose_codiige`):** Tabla alfanumérica auxiliar (se importa como `siose_codiige`).
  * **Clasificación de Usos (`t_siose_hilucs`):** Tabla alfanumérica auxiliar (se importa como `siose_hilucs`).
* **Campos clave de interés:**
  * En `T_POLIGONOS`: `ID_POLYGON` (ID único de polígono), `CODIIGE` (Código numérico de cobertura), `HILUCS` (Código numérico de uso de suelo).
  * En `t_siose_codiige`: `codiige`, `descripcion` (Definición textual de cobertura).
  * En `t_siose_hilucs`: `hilucs`, `descripcion` (Definición textual de uso HILUCS).

---

## 7. Estrategia de Proyección y Recorte para `jcm2`
1. **Reproyección Geométrica**: Las capas provenientes de Catastro y SIOSE ya están en el sistema de coordenadas de destino (**EPSG:25830**). Las capas de Límites Base, Transporte e Hidrografía, georreferenciadas en **ETRS89** (coordenadas geográficas), son proyectadas dinámicamente en el modelo de base de datos a `EPSG:25830` usando `ST_Transform(geom, 25830)`.
2. **Reducción de Dimensiones (2D)**: Capas con coordenadas 3D (Z) como `tramovial` son transformadas a dos dimensiones mediante `ST_Force2D`.
3. **Filtro y Recorte de 500 metros**: Para limitar el análisis al municipio de Estepona reduciendo el volumen de datos de capas de ámbito provincial/nacional, se realiza un recorte espacial utilizando un buffer de **500 metros** alrededor de la geometría municipal seleccionada en `jcm2.ttmm` mediante la condición de proximidad indexada `ST_DWithin`.
