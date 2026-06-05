-- ============================================================================
-- SCRIPT DE PROCESAMIENTO Y CREACIÓN DEL ESQUEMA jcm2 (ETL PASO A PASO)
-- Proyecto Final: Bases de Datos Espaciales
-- ============================================================================

-- 1. LIMPIEZA DE TABLAS EXISTENTES
-- ============================================================================
DROP TABLE IF EXISTS jcm2.building CASCADE;
DROP TABLE IF EXISTS jcm2.buildingpart CASCADE;
DROP TABLE IF EXISTS jcm2.cadastralparcel CASCADE;
DROP TABLE IF EXISTS jcm2.tramovial CASCADE;
DROP TABLE IF EXISTS jcm2.portalpk CASCADE;
DROP TABLE IF EXISTS jcm2.tramocurso CASCADE;
DROP TABLE IF EXISTS jcm2.siose_pol CASCADE;
DROP TABLE IF EXISTS jcm2.siose_codiige CASCADE;
DROP TABLE IF EXISTS jcm2.siose_hilucs CASCADE;
DROP TABLE IF EXISTS jcm2.ttmm CASCADE;
DROP TABLE IF EXISTS jcm2.log_calidad_geometrias CASCADE;

-- 1.1. Creación de Tabla de Registro de Calidad y Trazabilidad
CREATE TABLE jcm2.log_calidad_geometrias (
    tabla varchar(50) PRIMARY KEY,
    total_origen_buffer integer DEFAULT 0,
    originales_validas integer DEFAULT 0,
    originales_invalidas integer DEFAULT 0,
    reparadas_exito integer DEFAULT 0,
    corruptas_descartadas integer DEFAULT 0,
    filtradas_conversion_2d integer DEFAULT 0,
    filtradas_escala integer DEFAULT 0
);

-- 2. CREACIÓN DE TABLAS CON EL SRS DEL PROYECTO ({{SRID_PROYECTO}}) Y 2D
-- ============================================================================

-- 2.1. Término Municipal (ttmm)
CREATE TABLE jcm2.ttmm (
    gid serial PRIMARY KEY,
    inspireid varchar,
    natcode varchar,
    nameunit varchar,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}})
);

-- 2.2. Edificios (building)
CREATE TABLE jcm2.building (
    gid serial PRIMARY KEY,
    gml_id varchar,
    current_use_in varchar,
    currentuse varchar,
    numberofbuildingunits integer,
    value integer,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}})
);

-- 2.3. Partes de Edificios (buildingpart)
CREATE TABLE jcm2.buildingpart (
    gid serial PRIMARY KEY,
    gml_id varchar,
    numberoffloorsaboveground integer,
    numberoffloorsbelowground integer,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}})
);

-- 2.4. Parcelas Catastrales (cadastralparcel)
CREATE TABLE jcm2.cadastralparcel (
    gid serial PRIMARY KEY,
    gml_id varchar,
    areavalue numeric,
    localid varchar,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}})
);

-- 2.5. Tramos Viales (tramovial)
CREATE TABLE jcm2.tramovial (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    clased varchar,
    nombre varchar,
    firmed varchar,
    geom geometry(MultiLineString, {{SRID_PROYECTO}})
);

-- 2.6. Portales y Puntos Kilométricos (portalpk)
CREATE TABLE jcm2.portalpk (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    id_porpk varchar,
    numero varchar,
    geom geometry(MultiPoint, {{SRID_PROYECTO}})
);

-- 2.7. Red de Hidrografía (tramocurso)
CREATE TABLE jcm2.tramocurso (
    gid serial PRIMARY KEY,
    id_curso varchar,
    nombre varchar,
    tipo_curso varchar,
    geom geometry(MultiLineString, {{SRID_PROYECTO}})
);

-- 2.8. SIOSE Polígonos (siose_pol)
CREATE TABLE jcm2.siose_pol (
    gid serial PRIMARY KEY,
    id_polygon varchar,
    codiige integer,
    hilucs integer,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}})
);


-- 3. INSERCIÓN DE DATOS PASO A PASO (PROCESAMIENTO Y DEPURACIÓN)
-- ============================================================================

-- 3.1. Insertar el Municipio de Estudio (Estepona)
-- SRID de origne 4258
INSERT INTO jcm2.ttmm (inspireid, natcode, nameunit, geom)
SELECT inspireid, natcode, nameunit, ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(geom, {{SRID_PROYECTO}}))))
FROM jcm1.ttmm
WHERE (natcode = '3417' || SUBSTRING('{{CODIGO_MUNICIPIO}}', 1, 2) || '{{CODIGO_MUNICIPIO}}'
   OR natcode LIKE '%' || '{{CODIGO_MUNICIPIO}}')
  AND geom IS NOT NULL;

-- Crear el índice espacial permanente e inmediato en jcm2.ttmm
CREATE INDEX jcm2_ttmm_geom_idx ON jcm2.ttmm USING gist(geom);

-- Log inicial para la tabla municipal (ttmm)
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'ttmm',
    COUNT(*),
    COUNT(CASE WHEN ST_IsValid(geom) THEN 1 END),
    COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END),
    COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END),
    0,
    0,
    0
FROM jcm2.ttmm;


-- 3.2. PROCESAMIENTO SECUENCIAL: EDIFICIOS (building)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_building (
    gid serial PRIMARY KEY,
    gml_id varchar,
    current_use_in varchar,
    currentuse varchar,
    numberofbuildingunits integer,
    value integer,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal (ST_DWithin reproyectando al vuelo si difieren)
INSERT INTO jcm2.stage_building (gml_id, current_use_in, numberofbuildingunits, value, geom_raw, srid_original, es_valida_original)
SELECT b.gml_id, b.currentuse, b.numberofbuildingunits, b.value, b.geom, ST_SRID(b.geom), ST_IsValid(b.geom)
FROM jcm1.building b, jcm2.ttmm m
WHERE b.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(b.geom) = {{SRID_PROYECTO}} THEN b.geom ELSE ST_Transform(b.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección de Geometría (Solo a no válidas)
UPDATE jcm2.stage_building SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_building SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_building 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso C: Mapeo de Atributos Semánticos e INSPIRE
UPDATE jcm2.stage_building
SET currentuse = CASE 
        WHEN current_use_in = '1_residential' THEN 'residential'
        WHEN current_use_in = '2_agriculture' THEN 'agriculture'
        WHEN current_use_in = '3_industrial' THEN 'industrial'
        WHEN current_use_in = '4_2_retail' THEN 'commerceAndServices'
        WHEN current_use_in = '4_3_publicServices' THEN 'publicServices'
        WHEN current_use_in = '4_1_office' THEN 'office'
        ELSE NULL
    END,
    numberofbuildingunits = GREATEST(0, numberofbuildingunits),
    value = GREATEST(0, value);

-- Paso D: Conversión a 2D (Force2D) y Verificación de daños
UPDATE jcm2.stage_building SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_building
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Filtro de Escala/Microgeometrías
UPDATE jcm2.stage_building
SET descartada_escala = true
WHERE ST_Area(geom_temp) < 0.5;

-- Paso F: Registro de Métricas de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'building',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_building;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.building (gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom)
SELECT gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom_temp
FROM jcm2.stage_building
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion
  AND NOT descartada_escala;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_building;


-- 3.3. PROCESAMIENTO SECUENCIAL: PARTES DE EDIFICIOS (buildingpart)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_buildingpart (
    gid serial PRIMARY KEY,
    gml_id varchar,
    numberoffloorsaboveground integer,
    numberoffloorsbelowground integer,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom_raw, srid_original, es_valida_original)
SELECT bp.gml_id, bp.numberoffloorsaboveground, bp.numberoffloorsbelowground, bp.geom, ST_SRID(bp.geom), ST_IsValid(bp.geom)
FROM jcm1.buildingpart bp, jcm2.ttmm m
WHERE bp.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(bp.geom) = {{SRID_PROYECTO}} THEN bp.geom ELSE ST_Transform(bp.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_buildingpart SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_buildingpart SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_buildingpart 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso C: Mapeo de Atributos Semánticos
UPDATE jcm2.stage_buildingpart
SET numberoffloorsaboveground = GREATEST(0, numberoffloorsaboveground),
    numberoffloorsbelowground = GREATEST(0, numberoffloorsbelowground);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_buildingpart SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_buildingpart
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Filtro de Escala
UPDATE jcm2.stage_buildingpart
SET descartada_escala = true
WHERE ST_Area(geom_temp) < 0.5;

-- Paso F: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'buildingpart',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_buildingpart;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
SELECT gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom_temp
FROM jcm2.stage_buildingpart
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion
  AND NOT descartada_escala;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_buildingpart;


-- 3.4. PROCESAMIENTO SECUENCIAL: PARCELAS CATASTRALES (cadastralparcel)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_cadastralparcel (
    gid serial PRIMARY KEY,
    gml_id varchar,
    areavalue numeric,
    localid varchar,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_cadastralparcel (gml_id, areavalue, localid, geom_raw, srid_original, es_valida_original)
SELECT cp.gml_id, cp.areavalue, cp.localid, cp.geom, ST_SRID(cp.geom), ST_IsValid(cp.geom)
FROM jcm1.cadastralparcel cp, jcm2.ttmm m
WHERE cp.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(cp.geom) = {{SRID_PROYECTO}} THEN cp.geom ELSE ST_Transform(cp.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_cadastralparcel SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_cadastralparcel SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_cadastralparcel 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_cadastralparcel SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_cadastralparcel
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Filtro de Escala
UPDATE jcm2.stage_cadastralparcel
SET descartada_escala = true
WHERE ST_Area(geom_temp) < 0.5;

-- Paso F: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'cadastralparcel',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_cadastralparcel;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.cadastralparcel (gml_id, areavalue, localid, geom)
SELECT gml_id, areavalue, localid, geom_temp
FROM jcm2.stage_cadastralparcel
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion
  AND NOT descartada_escala;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_cadastralparcel;


-- 3.5. PROCESAMIENTO SECUENCIAL: TRAMOS VIALES (tramovial)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_tramovial (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    clased varchar,
    nombre varchar,
    firmed varchar,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_simpleza boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_tramovial (id_tramo, id_vial, clased, nombre, firmed, geom_raw, srid_original, es_valida_original)
SELECT tv.id_tramo, tv.id_vial, tv.clased, tv.nombre, tv.firmed, tv.geom, ST_SRID(tv.geom), ST_IsValid(tv.geom)
FROM jcm1.tramovial tv, jcm2.ttmm m
WHERE tv.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(tv.geom) = {{SRID_PROYECTO}} THEN tv.geom ELSE ST_Transform(tv.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_tramovial SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_tramovial SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_tramovial 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_tramovial SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_tramovial
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Control de Simpleza
UPDATE jcm2.stage_tramovial
SET descartada_simpleza = true
WHERE NOT ST_IsSimple(geom_temp);

-- Paso F: Filtro de Escala
UPDATE jcm2.stage_tramovial
SET descartada_escala = true
WHERE ST_Length(geom_temp) < 0.5;

-- Paso G: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'tramovial',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion OR descartada_simpleza THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_tramovial;

-- Paso H: Carga Definitiva
INSERT INTO jcm2.tramovial (id_tramo, id_vial, clased, nombre, firmed, geom)
SELECT id_tramo, id_vial, clased, nombre, firmed, geom_temp
FROM jcm2.stage_tramovial
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion
  AND NOT descartada_simpleza
  AND NOT descartada_escala;

-- Paso I: Limpieza
DROP TABLE IF EXISTS jcm2.stage_tramovial;


-- 3.6. PROCESAMIENTO SECUENCIAL: PORTALES Y PKs (portalpk)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_portalpk (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    id_porpk varchar,
    numero varchar,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_portalpk (id_tramo, id_vial, id_porpk, numero, geom_raw, srid_original, es_valida_original)
SELECT pk.id_tramo, pk.id_vial, pk.id_porpk, pk.numero, pk.geom, ST_SRID(pk.geom), ST_IsValid(pk.geom)
FROM jcm1.portalpk pk, jcm2.ttmm m
WHERE pk.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(pk.geom) = {{SRID_PROYECTO}} THEN pk.geom ELSE ST_Transform(pk.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_portalpk SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_portalpk SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_portalpk 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_portalpk SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_portalpk
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso F: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'portalpk',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    0
FROM jcm2.stage_portalpk;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.portalpk (id_tramo, id_vial, id_porpk, numero, geom)
SELECT id_tramo, id_vial, id_porpk, numero, geom_temp
FROM jcm2.stage_portalpk
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_portalpk;


-- 3.7. PROCESAMIENTO SECUENCIAL: CURSOS DE AGUA (tramocurso)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_tramocurso (
    gid serial PRIMARY KEY,
    id_curso varchar,
    nombre varchar,
    tipo_curso varchar,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_tramocurso (id_curso, nombre, tipo_curso, geom_raw, srid_original, es_valida_original)
SELECT tc.id_curso, tc.nombre, tc.tipo_curso, tc.geom, ST_SRID(tc.geom), ST_IsValid(tc.geom)
FROM jcm1.tramocurso tc, jcm2.ttmm m
WHERE tc.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(tc.geom) = {{SRID_PROYECTO}} THEN tc.geom ELSE ST_Transform(tc.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_tramocurso SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_tramocurso SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_tramocurso 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_tramocurso SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_tramocurso
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Filtro de Escala
UPDATE jcm2.stage_tramocurso
SET descartada_escala = true
WHERE ST_Length(geom_temp) < 0.5;

-- Paso F: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'tramocurso',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_tramocurso;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.tramocurso (id_curso, nombre, tipo_curso, geom)
SELECT id_curso, nombre, tipo_curso, geom_temp
FROM jcm2.stage_tramocurso
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_conversion
  AND NOT descartada_escala;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_tramocurso;


-- 3.8. PROCESAMIENTO SECUENCIAL: SIOSE POLÍGONOS (siose_pol)
-- ----------------------------------------------------------------------------
CREATE TABLE jcm2.stage_siose_pol (
    gid serial PRIMARY KEY,
    id_polygon varchar,
    codiige integer,
    hilucs integer,
    geom_raw geometry,
    geom_temp geometry,
    srid_original integer,
    es_valida_original boolean,
    es_valida_post_correccion boolean DEFAULT true,
    vacia_post_correccion boolean DEFAULT false,
    descartada_referencial boolean DEFAULT false,
    descartada_conversion boolean DEFAULT false,
    descartada_escala boolean DEFAULT false
);

-- Paso A: Filtro municipal
INSERT INTO jcm2.stage_siose_pol (id_polygon, codiige, hilucs, geom_raw, srid_original, es_valida_original)
SELECT s.id_polygon, s.codiige, s.hilucs, s.geom, ST_SRID(s.geom), ST_IsValid(s.geom)
FROM jcm1.siose_pol s, jcm2.ttmm m
WHERE s.geom IS NOT NULL AND ST_DWithin(
    CASE WHEN ST_SRID(s.geom) = {{SRID_PROYECTO}} THEN s.geom ELSE ST_Transform(s.geom, {{SRID_PROYECTO}}) END,
    m.geom,
    500
);

-- Paso B: Reproyección y Corrección
UPDATE jcm2.stage_siose_pol SET geom_temp = ST_Transform(geom_raw, {{SRID_PROYECTO}});
UPDATE jcm2.stage_siose_pol SET geom_temp = ST_MakeValid(geom_temp) WHERE NOT es_valida_original;
UPDATE jcm2.stage_siose_pol 
SET es_valida_post_correccion = ST_IsValid(geom_temp),
    vacia_post_correccion = ST_IsEmpty(geom_temp);

-- Paso C: Integridad Referencial de Claves Foráneas
UPDATE jcm2.stage_siose_pol
SET descartada_referencial = true
WHERE codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige)
   OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs);

-- Paso D: Conversión a 2D y Control de Daños
UPDATE jcm2.stage_siose_pol SET geom_temp = ST_Multi(ST_Force2D(geom_temp));
UPDATE jcm2.stage_siose_pol
SET descartada_conversion = true
WHERE NOT ST_IsValid(geom_temp) OR ST_IsEmpty(geom_temp);

-- Paso E: Filtro de Escala
UPDATE jcm2.stage_siose_pol
SET descartada_escala = true
WHERE ST_Area(geom_temp) < 0.5;

-- Paso F: Registro de Calidad
INSERT INTO jcm2.log_calidad_geometrias (tabla, total_origen_buffer, originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas, filtradas_conversion_2d, filtradas_escala)
SELECT 
    'siose_pol',
    COUNT(*),
    COUNT(CASE WHEN es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original THEN 1 END),
    COUNT(CASE WHEN NOT es_valida_original AND es_valida_post_correccion AND NOT vacia_post_correccion THEN 1 END),
    COUNT(CASE WHEN (NOT es_valida_original AND NOT es_valida_post_correccion) OR vacia_post_correccion OR descartada_referencial THEN 1 END),
    COUNT(CASE WHEN descartada_conversion THEN 1 END),
    COUNT(CASE WHEN descartada_escala THEN 1 END)
FROM jcm2.stage_siose_pol;

-- Paso G: Carga Definitiva
INSERT INTO jcm2.siose_pol (id_polygon, codiige, hilucs, geom)
SELECT id_polygon, codiige, hilucs, geom_temp
FROM jcm2.stage_siose_pol
WHERE es_valida_post_correccion 
  AND NOT vacia_post_correccion
  AND NOT descartada_referencial
  AND NOT descartada_conversion
  AND NOT descartada_escala;

-- Paso H: Limpieza
DROP TABLE IF EXISTS jcm2.stage_siose_pol;


-- 3.9. Copiar Tablas Alfanuméricas SIOSE
-- ============================================================================
CREATE TABLE jcm2.siose_codiige AS SELECT * FROM jcm1.siose_codiige;
CREATE TABLE jcm2.siose_hilucs AS SELECT * FROM jcm1.siose_hilucs;


-- 4. VALIDACIÓN Y CORRECCIÓN GEOMÉTRICA (ST_MakeValid)
-- ============================================================================
-- NOTA: Sección vacía para compatibilidad de logs. La validación se realizó 
-- de manera preventiva y paso a paso durante la fase de staging.


-- 5. CREACIÓN DE ÍNDICES DEFINITIVOS
-- ============================================================================
CREATE INDEX jcm2_building_geom_idx ON jcm2.building USING gist(geom);
CREATE INDEX jcm2_buildingpart_geom_idx ON jcm2.buildingpart USING gist(geom);
CREATE INDEX jcm2_cadastralparcel_geom_idx ON jcm2.cadastralparcel USING gist(geom);
CREATE INDEX jcm2_tramovial_geom_idx ON jcm2.tramovial USING gist(geom);
CREATE INDEX jcm2_portalpk_geom_idx ON jcm2.portalpk USING gist(geom);
CREATE INDEX jcm2_tramocurso_geom_idx ON jcm2.tramocurso USING gist(geom);
CREATE INDEX jcm2_siose_pol_geom_idx ON jcm2.siose_pol USING gist(geom);

-- Índice de atributo para el uso de edificios (tanto original como INSPIRE)
CREATE INDEX jcm2_building_currentuse_idx ON jcm2.building (currentuse);
CREATE INDEX jcm2_building_current_use_in_idx ON jcm2.building (current_use_in);


-- 5.9. LIMPIEZA PREVENTIVA ANTES DE LAS RESTRICCIONES (CONSTRAINTS)
-- ============================================================================
-- NOTA: Sección vacía para compatibilidad de logs. La limpieza se realizó 
-- de manera preventiva y proactiva durante la fase de staging.


-- 6. ADICIÓN DE RESTRICCIONES (CONSTRAINTS) SEMÁNTICAS Y GEOMÉTRICAS
-- ============================================================================

-- 6.1. Restricciones de Geometría Válida (ST_IsValid)
ALTER TABLE jcm2.ttmm ADD CONSTRAINT chk_ttmm_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.tramocurso ADD CONSTRAINT chk_tramocurso_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_valid CHECK (ST_IsValid(geom));

-- 6.2. Restricción de Elementos de Red Lineales Simples (ST_IsSimple)
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_simple CHECK (ST_IsSimple(geom));

-- 6.3. Restricciones de Dimensiones Mínimas Admisibles (Escala 1:5000)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_length CHECK (ST_Length(geom) >= 0.5);
ALTER TABLE jcm2.tramocurso ADD CONSTRAINT chk_tramocurso_geom_length CHECK (ST_Length(geom) >= 0.5);

-- 6.4. Restricciones de Campos Alfanuméricos Positivos
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_units CHECK (numberofbuildingunits >= 0);
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_value CHECK (value >= 0);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_up CHECK (numberoffloorsaboveground >= 0);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_down CHECK (numberoffloorsbelowground >= 0);

-- 6.5. Restricción de Dominio Acotado para currentuse (INSPIRE)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_currentuse CHECK (
    currentuse IN (
        'residential', 'agriculture', 'industrial', 'commerceAndServices', 
        'publicServices', 'office', 'educational', 'health', 
        'recreational', 'other', 'ancillary'
    ) OR currentuse IS NULL
);

-- 6.6. Configuración de Claves Primarias y Foráneas en SIOSE
-- Establecer Claves Primarias en tablas alfanuméricas auxiliares
ALTER TABLE jcm2.siose_codiige ADD CONSTRAINT pk_siose_codiige PRIMARY KEY (codiige);
ALTER TABLE jcm2.siose_hilucs ADD CONSTRAINT pk_siose_hilucs PRIMARY KEY (hilucs);

-- Establecer Claves Foráneas de integridad referencial
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_codiige FOREIGN KEY (codiige) REFERENCES jcm2.siose_codiige(codiige);
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_hilucs FOREIGN KEY (hilucs) REFERENCES jcm2.siose_hilucs(hilucs);
