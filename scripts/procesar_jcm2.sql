-- ============================================================================
-- SCRIPT DE PROCESAMIENTO Y CREACIÓN DEL ESQUEMA jcm2 (ETL EN CTEs DE UNA PASADA)
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
DROP TABLE IF EXISTS jcm2.municipio CASCADE;
DROP TABLE IF EXISTS jcm2.log_calidad_geometrias CASCADE;
DROP TABLE IF EXISTS jcm2.log_detalle_calidad CASCADE;

-- 1.1. Creación de Tabla de Registro de Calidad y Trazabilidad (Métricas Agregadas)
CREATE TABLE jcm2.log_calidad_geometrias (
    tabla                   varchar(64) PRIMARY KEY,
    ts_proceso              timestamptz NOT NULL DEFAULT now(),
    srid_origen             integer,
    srid_proyecto           integer,
    total_origen_buffer     integer DEFAULT 0,
    originales_validas      integer DEFAULT 0,
    originales_invalidas    integer DEFAULT 0,
    reparadas_exito         integer DEFAULT 0,
    corruptas_descartadas   integer DEFAULT 0,
    filtradas_conversion_2d integer DEFAULT 0,
    filtradas_escala        integer DEFAULT 0,
    insertadas_destino      integer DEFAULT 0,
    notas                   text
);

-- 1.2. Creación de Tabla de Detalle de Auditoría Geométrica (Trazabilidad Fila a Fila)
CREATE TABLE jcm2.log_detalle_calidad (
    id                      serial PRIMARY KEY,
    tabla                   varchar(64) NOT NULL,
    gml_id                  varchar,
    srid_original           integer,
    es_valida_original      boolean NOT NULL,
    valida_post_corr        boolean,
    vacia_post_corr         boolean,
    motivo_descarte         varchar, -- 'corrupta', 'rota_conversion', 'escala_micro'
    geom_original           geometry(Geometry, {{SRID_PROYECTO}})
);


-- 2. CREACIÓN DE TABLAS DESTINO CON EL SRS DEL PROYECTO ({{SRID_PROYECTO}})
-- ============================================================================

-- 2.1. Término Municipal (municipio)
CREATE TABLE jcm2.municipio (
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


-- 3. INSERCIÓN DE DATOS PASO A PASO (PROCESAMIENTO, DEPURACIÓN Y LOGS)
-- ============================================================================

-- 3.1. Procesamiento de municipio (Término Municipal)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'municipio';

WITH candidatos AS (
    SELECT
        inspireid,
        natcode,
        nameunit,
        geom                                      AS geom_raw,
        ST_SRID(geom)                             AS srid_raw,
        ST_Transform(geom, {{SRID_PROYECTO}})     AS geom_proj
    FROM jcm1.ttmm
    WHERE (natcode = '3401' || SUBSTRING('{{CODIGO_MUNICIPIO}}', 1, 2) || '{{CODIGO_MUNICIPIO}}'
        OR natcode = '3417' || SUBSTRING('{{CODIGO_MUNICIPIO}}', 1, 2) || '{{CODIGO_MUNICIPIO}}')
      AND geom IS NOT NULL
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        inspireid,
        natcode,
        nameunit,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))    AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        FALSE                                                         AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final)) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.municipio (inspireid, natcode, nameunit, geom)
    SELECT inspireid, natcode, nameunit, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'municipio', inspireid, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        0                                               AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'municipio', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Índice espacial inmediato para municipio (crítico para las búsquedas del buffer en las siguientes capas)
CREATE INDEX jcm2_municipio_geom_idx ON jcm2.municipio USING gist(geom);
ANALYZE jcm2.municipio;


-- 3.2. Procesamiento de Edificios (building)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'building';

WITH candidatos AS (
    SELECT
        b.gml_id,
        b.currentuse                              AS current_use_in,
        b.numberofbuildingunits                   AS units_raw,
        b.value                                   AS value_raw,
        b.geom                                    AS geom_raw,
        ST_SRID(b.geom)                           AS srid_raw,
        ST_Transform(b.geom, {{SRID_PROYECTO}})   AS geom_proj
    FROM jcm1.building b
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE b.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(b.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        gml_id,
        current_use_in,
        CASE current_use_in
            WHEN '1_residential'       THEN 'residential'
            WHEN '2_agriculture'       THEN 'agriculture'
            WHEN '3_industrial'        THEN 'industrial'
            WHEN '4_2_retail'          THEN 'commerceAndServices'
            WHEN '4_3_publicServices'  THEN 'publicServices'
            WHEN '4_1_office'          THEN 'office'
            WHEN '5_educational'       THEN 'educational'
            WHEN '6_health'            THEN 'health'
            WHEN '7_recreational'      THEN 'recreational'
            WHEN '8_other'             THEN 'other'
            WHEN '9_ancillary'         THEN 'ancillary'
            ELSE NULL
        END                                                    AS currentuse,
        COALESCE(GREATEST(0, units_raw), 0)                   AS numberofbuildingunits,
        COALESCE(GREATEST(0, value_raw), 0)                   AS value,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) < 0.5) AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) >= 0.5) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.building (gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom)
    SELECT gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'building', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'building', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM clasificados
            WHERE current_use_in IS NOT NULL AND currentuse IS NULL
        )
        THEN 'ADVERTENCIA: existen valores de current_use_in sin mapeo INSPIRE.'
        ELSE NULL
    END
FROM metricas;

-- Validación de consistencia lógica para building
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'building';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para building: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'building · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.building;


-- 3.3. Procesamiento de Partes de Edificios (buildingpart)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'buildingpart';

WITH candidatos AS (
    SELECT
        bp.gml_id,
        bp.numberoffloorsaboveground              AS floors_above_raw,
        bp.numberoffloorsbelowground              AS floors_below_raw,
        bp.geom                                   AS geom_raw,
        ST_SRID(bp.geom)                          AS srid_raw,
        ST_Transform(bp.geom, {{SRID_PROYECTO}})  AS geom_proj
    FROM jcm1.buildingpart bp
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE bp.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(bp.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        gml_id,
        COALESCE(GREATEST(0, floors_above_raw), 0)            AS numberoffloorsaboveground,
        COALESCE(GREATEST(0, floors_below_raw), 0)            AS numberoffloorsbelowground,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) < 0.5) AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) >= 0.5) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
    SELECT gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'buildingpart', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'buildingpart', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para buildingpart
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'buildingpart';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para buildingpart: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'buildingpart · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.buildingpart;


-- 3.4. Procesamiento de Parcelas Catastrales (cadastralparcel)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'cadastralparcel';

WITH candidatos AS (
    SELECT
        cp.gml_id,
        cp.areavalue,
        cp.localid,
        cp.geom                                   AS geom_raw,
        ST_SRID(cp.geom)                          AS srid_raw,
        ST_Transform(cp.geom, {{SRID_PROYECTO}})  AS geom_proj
    FROM jcm1.cadastralparcel cp
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE cp.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(cp.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        gml_id,
        areavalue,
        localid,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) < 0.5) AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) >= 0.5) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.cadastralparcel (gml_id, areavalue, localid, geom)
    SELECT gml_id, areavalue, localid, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'cadastralparcel', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'cadastralparcel', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para cadastralparcel
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'cadastralparcel';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para cadastralparcel: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'cadastralparcel · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.cadastralparcel;


-- 3.5. Procesamiento de Tramos Viales (tramovial)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'tramovial';

WITH candidatos AS (
    SELECT
        tv.id_tramo,
        tv.id_vial,
        tv.clased,
        tv.nombre,
        tv.firmed,
        tv.geom                                   AS geom_raw,
        ST_SRID(tv.geom)                          AS srid_raw,
        ST_Transform(tv.geom, {{SRID_PROYECTO}})  AS geom_proj
    FROM jcm1.tramovial tv
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE tv.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(tv.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        id_tramo,
        id_vial,
        clased,
        nombre,
        firmed,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        -- Non-simple or invalid/empty lines count under es_rota_conversion
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final) OR NOT ST_IsSimple(geom_final))) AS es_rota_conversion,
        FALSE                                                                                                                                          AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_IsSimple(geom_final)) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.tramovial (id_tramo, id_vial, clased, nombre, firmed, geom)
    SELECT id_tramo, id_vial, clased, nombre, firmed, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'tramovial', id_tramo, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'tramovial', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para tramovial
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'tramovial';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para tramovial: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'tramovial · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.tramovial;


-- 3.6. Procesamiento de Portales y PKs (portalpk)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'portalpk';

WITH candidatos AS (
    SELECT
        pk.id_tramo,
        pk.id_vial,
        pk.id_porpk,
        pk.numero,
        pk.geom                                   AS geom_raw,
        ST_SRID(pk.geom)                          AS srid_raw,
        ST_Transform(pk.geom, {{SRID_PROYECTO}})  AS geom_proj
    FROM jcm1.portalpk pk
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE pk.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(pk.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        id_porpk                                              AS gml_id, -- identificador único
        id_tramo,
        id_vial,
        numero,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        FALSE                                                          AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final)) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.portalpk (id_tramo, id_vial, id_porpk, numero, geom)
    SELECT id_tramo, id_vial, gml_id, numero, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'portalpk', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        0                                               AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'portalpk', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para portalpk
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'portalpk';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para portalpk: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'portalpk · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.portalpk;


-- 3.7. Procesamiento de Red de Hidrografía (tramocurso)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'tramocurso';

WITH candidatos AS (
    SELECT
        tc.id_curso,
        tc.nombre,
        tc.tipo_curso,
        tc.geom                                   AS geom_raw,
        ST_SRID(tc.geom)                          AS srid_raw,
        ST_Transform(tc.geom, {{SRID_PROYECTO}})  AS geom_proj
    FROM jcm1.tramocurso tc
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE tc.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(tc.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        id_curso                                               AS gml_id, -- identificador único
        nombre,
        tipo_curso,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (NOT valida_en_proj AND (NOT valida_final OR vacia_final))     AS es_corrupta,
        (valida_final AND NOT vacia_final AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        FALSE                                                                                                               AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final)) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.tramocurso (id_curso, nombre, tipo_curso, geom)
    SELECT gml_id, nombre, tipo_curso, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'tramocurso', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'tramocurso', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para tramocurso
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'tramocurso';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para tramocurso: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'tramocurso · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.tramocurso;


-- 3.8. Procesamiento de SIOSE Polígonos (siose_pol)
-- ----------------------------------------------------------------------------
DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'siose_pol';

WITH candidatos AS (
    SELECT
        s.id_polygon,
        s.codiige,
        s.hilucs,
        s.geom                                    AS geom_raw,
        ST_SRID(s.geom)                           AS srid_raw,
        ST_Transform(s.geom, {{SRID_PROYECTO}})   AS geom_proj
    FROM jcm1.siose_pol s
    CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
    WHERE s.geom IS NOT NULL
      AND ST_DWithin(
          ST_Transform(s.geom, {{SRID_PROYECTO}}),
          m.geom,
          500
      )
),
saneados AS (
    SELECT
        c.*,
        ST_IsValid(c.geom_proj) AS valida_en_proj,
        l.geom_final,
        ST_IsValid(l.geom_final) AS valida_final,
        ST_IsEmpty(l.geom_final) AS vacia_final
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT ST_Multi(ST_Force2D(CASE WHEN ST_IsValid(c.geom_proj) THEN c.geom_proj ELSE ST_MakeValid(c.geom_proj) END)) AS geom_final
    ) l
),
clasificados AS (
    SELECT
        srid_raw,
        id_polygon                                            AS gml_id, -- identificador único
        codiige,
        hilucs,
        geom_raw,
        geom_proj,
        geom_final,
        valida_en_proj,
        valida_final,
        vacia_final,
        (codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige)
         OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs)) AS es_incoherente_ref,
        (((NOT valida_en_proj AND (NOT valida_final OR vacia_final))
         OR (codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige)
             OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs)))) AS es_corrupta,
        (valida_final AND NOT vacia_final AND NOT (codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige) OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs)) AND (geom_final IS NULL OR NOT ST_IsValid(geom_final) OR ST_IsEmpty(geom_final))) AS es_rota_conversion,
        (valida_final AND NOT vacia_final AND NOT (codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige) OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs)) AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) < 0.5) AS es_filtrada_escala,
        (valida_final AND NOT vacia_final AND NOT (codiige NOT IN (SELECT codiige FROM jcm1.siose_codiige) OR hilucs NOT IN (SELECT hilucs FROM jcm1.siose_hilucs)) AND geom_final IS NOT NULL AND ST_IsValid(geom_final) AND NOT ST_IsEmpty(geom_final) AND ST_Area(geom_final) >= 0.5) AS es_apta
    FROM saneados
),
insert_destino AS (
    INSERT INTO jcm2.siose_pol (id_polygon, codiige, hilucs, geom)
    SELECT gml_id, codiige, hilucs, geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid
),
insert_auditoria AS (
    INSERT INTO jcm2.log_detalle_calidad (tabla, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original)
    SELECT 
        'siose_pol', gml_id, srid_raw, valida_en_proj, valida_final, vacia_final,
        CASE 
            WHEN es_corrupta THEN 'corrupta'
            WHEN es_rota_conversion THEN 'rota_conversion'
            WHEN es_filtrada_escala THEN 'escala_micro'
        END,
        ST_Force2D(geom_proj)
    FROM clasificados
    WHERE NOT es_apta OR NOT valida_en_proj
),
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj AND es_apta) AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insert_destino)           AS insertadas_destino,
        COALESCE(MAX(srid_raw), 0)                      AS srid_raw
    FROM clasificados
)
INSERT INTO jcm2.log_calidad_geometrias (
    tabla, ts_proceso, srid_origen, srid_proyecto, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, notas
)
SELECT
    'siose_pol', now(), srid_raw, {{SRID_PROYECTO}}, total_origen_buffer,
    originales_validas, originales_invalidas, reparadas_exito, corruptas_descartadas,
    filtradas_conversion_2d, filtradas_escala, insertadas_destino, NULL
FROM metricas;

-- Validación de consistencia lógica para siose_pol
DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r FROM jcm2.log_calidad_geometrias WHERE tabla = 'siose_pol';
    suma_categorias := COALESCE(r.corruptas_descartadas, 0) + COALESCE(r.filtradas_conversion_2d, 0) + COALESCE(r.filtradas_escala, 0) + COALESCE(r.insertadas_destino, 0);
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION 'LOG INCONSISTENTE para siose_pol: total=% != suma=%', r.total_origen_buffer, suma_categorias;
    END IF;
    RAISE NOTICE 'siose_pol · % procesados → % insertados', r.total_origen_buffer, r.insertadas_destino;
END;
$$;
ANALYZE jcm2.siose_pol;


-- 3.9. Copiar Tablas Alfanuméricas SIOSE
-- ============================================================================
CREATE TABLE jcm2.siose_codiige (
    codiige integer,
    descripcion varchar,
    color_html varchar(7)
);
INSERT INTO jcm2.siose_codiige (codiige, descripcion)
SELECT codiige, descripcion FROM jcm1.siose_codiige;

CREATE TABLE jcm2.siose_hilucs (
    hilucs integer,
    descripcion varchar,
    color_html varchar(7)
);
INSERT INTO jcm2.siose_hilucs (hilucs, descripcion)
SELECT hilucs, descripcion FROM jcm1.siose_hilucs;

-- Mapeo de colores oficiales SIOSE desde los archivos SLD
UPDATE jcm2.siose_codiige SET color_html = CASE codiige
    WHEN 111 THEN '#e65069'
    WHEN 112 THEN '#f06e82'
    WHEN 113 THEN '#ff8296'
    WHEN 114 THEN '#64b482'
    WHEN 121 THEN '#f27961'
    WHEN 122 THEN '#47ccb6'
    WHEN 123 THEN '#a07878'
    WHEN 130 THEN '#b679f2'
    WHEN 140 THEN '#f2aace'
    WHEN 150 THEN '#f5a27a'
    WHEN 161 THEN '#cc3d6d'
    WHEN 162 THEN '#e6cccc'
    WHEN 163 THEN '#e6cce6'
    WHEN 171 THEN '#a3a3bf'
    WHEN 172 THEN '#70694c'
    WHEN 210 THEN '#f2e8b6'
    WHEN 220 THEN '#ffffd2'
    WHEN 231 THEN '#e6aa5a'
    WHEN 232 THEN '#e6aa5a'
    WHEN 233 THEN '#c8a68c'
    WHEN 234 THEN '#f0e678'
    WHEN 235 THEN '#c8aa50'
    WHEN 236 THEN '#e6bd5f'
    WHEN 240 THEN '#eded5f'
    WHEN 250 THEN '#edd377'
    WHEN 260 THEN '#dded8e'
    WHEN 311 THEN '#50b051'
    WHEN 312 THEN '#109c69'
    WHEN 313 THEN '#38a65d'
    WHEN 320 THEN '#beed5f'
    WHEN 330 THEN '#82d957'
    WHEN 340 THEN '#58bf43'
    WHEN 351 THEN '#f0c864'
    WHEN 352 THEN '#d9d6c7'
    WHEN 353 THEN '#3c503c'
    WHEN 354 THEN '#d2f2c2'
    WHEN 411 THEN '#a6a6ff'
    WHEN 412 THEN '#6464ff'
    WHEN 413 THEN '#ccccff'
    WHEN 414 THEN '#e6e6ff'
    WHEN 511 THEN '#61aaf2'
    WHEN 512 THEN '#82bef2'
    WHEN 513 THEN '#91d2f2'
    WHEN 514 THEN '#4696ff'
    WHEN 515 THEN '#e6f2ff'
    WHEN 516 THEN '#a6e6cc'
    ELSE color_html
END;

UPDATE jcm2.siose_hilucs SET color_html = CASE hilucs
    WHEN 110 THEN '#ca5698'
    WHEN 120 THEN '#91cc61'
    WHEN 130 THEN '#4fd840'
    WHEN 140 THEN '#5c1dc8'
    WHEN 200 THEN '#2c65ce'
    WHEN 310 THEN '#2424d2'
    WHEN 330 THEN '#e89b52'
    WHEN 340 THEN '#dd2f14'
    WHEN 410 THEN '#b736ea'
    WHEN 430 THEN '#4dd59f'
    WHEN 500 THEN '#88d0ee'
    WHEN 610 THEN '#c6dd68'
    WHEN 620 THEN '#64d0cb'
    WHEN 631 THEN '#db52d0'
    WHEN 632 THEN '#54c971'
    WHEN 660 THEN '#dc4868'
    ELSE color_html
END;


-- 4. VALIDACIÓN Y CORRECCIÓN GEOMÉTRICA (ST_MakeValid)
-- ============================================================================
-- NOTA: Sección vacía para compatibilidad de logs de validación. Todo el saneamiento 
-- geométrico se realiza al vuelo y de forma segura dentro de las CTEs.


-- 5. CREACIÓN DE ÍNDICES DEFINITIVOS
-- ============================================================================
-- Índices espaciales definitivos (bulk load ya ejecutado)
CREATE INDEX jcm2_building_geom_idx ON jcm2.building USING gist(geom);
CREATE INDEX jcm2_buildingpart_geom_idx ON jcm2.buildingpart USING gist(geom);
CREATE INDEX jcm2_cadastralparcel_geom_idx ON jcm2.cadastralparcel USING gist(geom);
CREATE INDEX jcm2_tramovial_geom_idx ON jcm2.tramovial USING gist(geom);
CREATE INDEX jcm2_portalpk_geom_idx ON jcm2.portalpk USING gist(geom);
CREATE INDEX jcm2_tramocurso_geom_idx ON jcm2.tramocurso USING gist(geom);
CREATE INDEX jcm2_siose_pol_geom_idx ON jcm2.siose_pol USING gist(geom);

-- Índice espacial de la tabla de auditoría detallada
CREATE INDEX jcm2_log_detalle_calidad_geom_idx ON jcm2.log_detalle_calidad USING gist(geom_original);

-- Índices de atributos
CREATE INDEX jcm2_building_currentuse_idx ON jcm2.building (currentuse);
CREATE INDEX jcm2_building_current_use_in_idx ON jcm2.building (current_use_in);

-- Índice expresional para optimización de JOINs de volumen (Q8.4)
CREATE INDEX jcm2_buildingpart_gml_id_prefix_idx ON jcm2.buildingpart (LEFT(gml_id, 25));

-- Claves primarias en tablas auxiliares alfanuméricas
ALTER TABLE jcm2.siose_codiige ADD CONSTRAINT pk_siose_codiige PRIMARY KEY (codiige);
ALTER TABLE jcm2.siose_hilucs ADD CONSTRAINT pk_siose_hilucs PRIMARY KEY (hilucs);

-- Ejecutar ANALYZE en todas las tablas para actualizar estadísticas de índices
ANALYZE jcm2.municipio;
ANALYZE jcm2.building;
ANALYZE jcm2.buildingpart;
ANALYZE jcm2.cadastralparcel;
ANALYZE jcm2.tramovial;
ANALYZE jcm2.portalpk;
ANALYZE jcm2.tramocurso;
ANALYZE jcm2.siose_pol;
ANALYZE jcm2.log_detalle_calidad;


-- 6. ADICIÓN DE RESTRICCIONES (CONSTRAINTS) SEMÁNTICAS Y GEOMÉTRICAS
-- ============================================================================
-- Nota: Uso de NOT VALID seguido de VALIDATE CONSTRAINT para optimización de bloqueos.

-- 6.1. Restricciones de Geometría Válida (ST_IsValid)
ALTER TABLE jcm2.municipio ADD CONSTRAINT chk_municipio_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.municipio VALIDATE CONSTRAINT chk_municipio_geom_valid;

ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.building VALIDATE CONSTRAINT chk_building_geom_valid;

ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.buildingpart VALIDATE CONSTRAINT chk_buildingpart_geom_valid;

ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.cadastralparcel VALIDATE CONSTRAINT chk_cadastralparcel_geom_valid;

ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.tramovial VALIDATE CONSTRAINT chk_tramovial_geom_valid;

ALTER TABLE jcm2.tramocurso ADD CONSTRAINT chk_tramocurso_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.tramocurso VALIDATE CONSTRAINT chk_tramocurso_geom_valid;

ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_valid CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.siose_pol VALIDATE CONSTRAINT chk_siose_pol_geom_valid;

-- 6.2. Restricción de Elementos de Red Lineales Simples (ST_IsSimple)
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_simple CHECK (ST_IsSimple(geom)) NOT VALID;
ALTER TABLE jcm2.tramovial VALIDATE CONSTRAINT chk_tramovial_geom_simple;

-- 6.3. Restricciones de Dimensiones Mínimas Admisibles (Escala 1:5000)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_area CHECK (ST_Area(geom) >= 0.5) NOT VALID;
ALTER TABLE jcm2.building VALIDATE CONSTRAINT chk_building_geom_area;

ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_area CHECK (ST_Area(geom) >= 0.5) NOT VALID;
ALTER TABLE jcm2.buildingpart VALIDATE CONSTRAINT chk_buildingpart_geom_area;

ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_area CHECK (ST_Area(geom) >= 0.5) NOT VALID;
ALTER TABLE jcm2.cadastralparcel VALIDATE CONSTRAINT chk_cadastralparcel_geom_area;

ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_area CHECK (ST_Area(geom) >= 0.5) NOT VALID;
ALTER TABLE jcm2.siose_pol VALIDATE CONSTRAINT chk_siose_pol_geom_area;
-- Restricciones de longitud mínima eliminadas para preservar conectividad en redes lineales (tramovial y tramocurso)

-- 6.4. Restricciones de Campos Alfanuméricos Positivos
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_units CHECK (numberofbuildingunits >= 0) NOT VALID;
ALTER TABLE jcm2.building VALIDATE CONSTRAINT chk_building_units;

ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_value CHECK (value >= 0) NOT VALID;
ALTER TABLE jcm2.building VALIDATE CONSTRAINT chk_building_value;

ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_up CHECK (numberoffloorsaboveground >= 0) NOT VALID;
ALTER TABLE jcm2.buildingpart VALIDATE CONSTRAINT chk_buildingpart_floors_up;

ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_down CHECK (numberoffloorsbelowground >= 0) NOT VALID;
ALTER TABLE jcm2.buildingpart VALIDATE CONSTRAINT chk_buildingpart_floors_down;

-- 6.5. Restricción de Dominio Acotado para currentuse (INSPIRE)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_currentuse CHECK (
    currentuse IN (
        'residential', 'agriculture', 'industrial', 'commerceAndServices', 
        'publicServices', 'office', 'educational', 'health', 
        'recreational', 'other', 'ancillary'
    ) OR currentuse IS NULL
) NOT VALID;
ALTER TABLE jcm2.building VALIDATE CONSTRAINT chk_building_currentuse;

-- 6.6. Restricciones de Integridad Referencial de Claves Foráneas en SIOSE
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_codiige FOREIGN KEY (codiige) REFERENCES jcm2.siose_codiige(codiige) NOT VALID;
ALTER TABLE jcm2.siose_pol VALIDATE CONSTRAINT fk_siose_pol_codiige;

ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_hilucs FOREIGN KEY (hilucs) REFERENCES jcm2.siose_hilucs(hilucs) NOT VALID;
ALTER TABLE jcm2.siose_pol VALIDATE CONSTRAINT fk_siose_pol_hilucs;
