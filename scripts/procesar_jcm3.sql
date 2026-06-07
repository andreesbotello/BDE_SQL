-- ============================================================================
-- SCRIPT DE PROCESAMIENTO Y ANÁLISIS DEL ESQUEMA jcm3 (PRODUCCIÓN E INTEGRIDAD)
-- Proyecto Final: Bases de Datos Espaciales
-- ============================================================================

-- 1. LIMPIEZA DE TABLAS Y VISTAS EXISTENTES EN jcm3
-- ============================================================================
DROP VIEW IF EXISTS jcm3.view_q8_5_2 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_5_1 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_4 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_3 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_2 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_1_3 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_1_2 CASCADE;
DROP VIEW IF EXISTS jcm3.view_q8_1_1 CASCADE;
DROP VIEW IF EXISTS jcm3.view_parcelas_candidatas_centro CASCADE;
DROP VIEW IF EXISTS jcm3.view_analisis_c5_portales CASCADE;
DROP VIEW IF EXISTS jcm3.view_analisis_c4_urbano CASCADE;
DROP VIEW IF EXISTS jcm3.view_analisis_c3_inundacion CASCADE;
DROP VIEW IF EXISTS jcm3.view_analisis_c2_acceso CASCADE;
DROP VIEW IF EXISTS jcm3.view_analisis_c1_area_vacias CASCADE;
DROP VIEW IF EXISTS jcm3.view_building_solapes_intersecciones CASCADE;
DROP VIEW IF EXISTS jcm3.view_building_solapes_agrupada CASCADE;
DROP VIEW IF EXISTS jcm3.view_building_solapes_agrupada_1m2 CASCADE;
DROP TABLE IF EXISTS jcm3.building_solapes_alfanumerica CASCADE;
DROP VIEW IF EXISTS jcm3.view_solapes_edificios CASCADE;
DROP VIEW IF EXISTS jcm3.view_cruces_viales_puntos CASCADE;
DROP VIEW IF EXISTS jcm3.view_cruces_viales_puntos_baseline CASCADE;
DROP VIEW IF EXISTS jcm3.view_vial_edificio_intersecciones CASCADE;
DROP VIEW IF EXISTS jcm3.view_vial_edificio_corregidos CASCADE;
DROP VIEW IF EXISTS jcm3.view_vial_edificio_no_resueltos CASCADE;
DROP TABLE IF EXISTS jcm3.vial_edificio_reporte CASCADE;
DROP TABLE IF EXISTS jcm3.vial_stubs_reporte CASCADE;

DROP TABLE IF EXISTS jcm3.building CASCADE;
DROP TABLE IF EXISTS jcm3.buildingpart CASCADE;
DROP TABLE IF EXISTS jcm3.cadastralparcel CASCADE;
DROP TABLE IF EXISTS jcm3.tramovial CASCADE;
DROP TABLE IF EXISTS jcm3.portalpk CASCADE;
DROP TABLE IF EXISTS jcm3.tramocurso CASCADE;
DROP TABLE IF EXISTS jcm3.siose_pol CASCADE;
DROP TABLE IF EXISTS jcm3.siose_codiige CASCADE;
DROP TABLE IF EXISTS jcm3.siose_hilucs CASCADE;
DROP TABLE IF EXISTS jcm3.municipio CASCADE;

DROP VIEW IF EXISTS jcm3.view_reporte_resumen_calidad CASCADE;
DROP VIEW IF EXISTS jcm3.view_resumen_calidad_antes_despues CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_inspire_edificios CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_inspire_viales CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_solapes_edificios CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_solapes_viales CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_cruces_sin_nodo CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_buildingpart_sin_building CASCADE;
DROP VIEW IF EXISTS jcm3.view_diag_buildingpart_huerfano CASCADE;

CREATE SCHEMA IF NOT EXISTS jcm3;

-- Eliminar restos de ejecuciones de prueba previas en jcm2
DELETE FROM jcm2.building WHERE gml_id = 'TEST_GML_ID_SOLAPADO';

-- ============================================================================
-- 1.5. VISTAS DE DIAGNÓSTICO PRE-CORRECCIÓN (SOBRE EL STAGING jcm2)
-- ============================================================================

-- Diagnóstico de identificadores nulos/duplicados en jcm2
CREATE OR REPLACE VIEW jcm3.view_diag_inspire_edificios AS
SELECT gid, gml_id, 'gml_id nulo o duplicado'::varchar as inconsistencia, geom
FROM jcm2.building
WHERE gml_id IS NULL 
   OR gml_id IN (SELECT gml_id FROM jcm2.building GROUP BY gml_id HAVING COUNT(*) > 1);

CREATE OR REPLACE VIEW jcm3.view_diag_inspire_viales AS
SELECT gid, id_tramo, 'id_tramo nulo o duplicado'::varchar as inconsistencia, geom
FROM jcm2.tramovial
WHERE id_tramo IS NULL 
   OR id_tramo IN (SELECT id_tramo FROM jcm2.tramovial GROUP BY id_tramo HAVING COUNT(*) > 1);

-- Diagnóstico de solapes espaciales pre-corrección
CREATE OR REPLACE VIEW jcm3.view_diag_solapes_edificios AS
SELECT (row_number() OVER ()::integer) AS gid,
       b1.gid AS building_gid1, b2.gid AS building_gid2, 
       b1.gml_id AS gml_id1, b2.gml_id AS gml_id2,
       ST_Area(ST_Intersection(b1.geom, b2.geom)) AS area_solape,
       ST_Multi(STX_Extract(ST_Intersection(b1.geom, b2.geom), 3))::geometry(MultiPolygon, {{SRID_PROYECTO}}) AS geom
FROM jcm2.building b1
JOIN jcm2.building b2 ON b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid;

CREATE OR REPLACE VIEW jcm3.view_diag_solapes_viales AS
SELECT (row_number() OVER ()::integer) AS gid,
       tv.gid AS tramovial_gid, b.gid AS building_gid,
       tv.id_tramo AS tramovial_id, b.gml_id AS building_gml_id,
       ST_Length(inter.geom_linea) AS longitud_interseccion,
       ST_Multi(inter.geom_linea)::geometry(MultiLineString, {{SRID_PROYECTO}}) AS geom
FROM jcm2.tramovial tv
JOIN jcm2.building b ON tv.geom && b.geom AND ST_Relate(tv.geom, b.geom, '1********')
CROSS JOIN LATERAL (
    SELECT STX_Extract(ST_Intersection(tv.geom, b.geom), 2) AS geom_linea
) inter
WHERE inter.geom_linea IS NOT NULL;

CREATE OR REPLACE VIEW jcm3.view_diag_cruces_sin_nodo AS
SELECT (row_number() OVER ()::integer) AS gid,
       q.tramovial_gid1, q.tramovial_gid2,
       q.tramovial_id1, q.tramovial_id2,
       q.geom
FROM (
    SELECT tv1.gid AS tramovial_gid1, tv2.gid AS tramovial_gid2,
           tv1.id_tramo AS tramovial_id1, tv2.id_tramo AS tramovial_id2,
           (ST_Dump(ST_Multi(inter.geom_punto))).geom::geometry(Point, {{SRID_PROYECTO}}) AS geom
    FROM jcm2.tramovial tv1
    JOIN jcm2.tramovial tv2 ON tv1.geom && tv2.geom AND ST_Relate(tv1.geom, tv2.geom, '0********') AND tv1.gid < tv2.gid
    CROSS JOIN LATERAL (
        SELECT STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1) AS geom_punto
    ) inter
) q;

-- Diagnóstico de contención BuildingPart -> Building
CREATE OR REPLACE VIEW jcm3.view_diag_buildingpart_sin_building AS
SELECT (row_number() OVER ()::integer) AS gid,
       bp.gid AS buildingpart_gid, bp.gml_id, 
       'BuildingPart no contenido en su Building padre'::varchar as inconsistencia,
       bp.geom
FROM jcm2.buildingpart bp
JOIN jcm2.building b ON LEFT(bp.gml_id, 25) = b.gml_id
WHERE NOT (b.geom && bp.geom AND ST_Contains(b.geom, bp.geom));

-- Diagnóstico de integridad referencial (huérfanos) BuildingPart -> Building
CREATE OR REPLACE VIEW jcm3.view_diag_buildingpart_huerfano AS
SELECT bp.gid, bp.gml_id, 'BuildingPart huérfano (sin Building padre)'::varchar as inconsistencia, bp.geom
FROM jcm2.buildingpart bp
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm2.building b 
    WHERE b.gml_id = LEFT(bp.gml_id, 25)
);

-- ============================================================================
-- 2. CREACIÓN DEL DDL DE JCM3 (RESTRICCIONES INSPIRE DE OBLIGATORIEDAD)
-- ============================================================================

CREATE TABLE jcm3.municipio (
    gid serial PRIMARY KEY,
    inspireid varchar NOT NULL UNIQUE,
    natcode varchar,
    nameunit varchar,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}}) NOT NULL
);

CREATE TABLE jcm3.building (
    gid serial PRIMARY KEY,
    gml_id varchar NOT NULL UNIQUE,
    current_use_in varchar,
    currentuse varchar,
    numberofbuildingunits integer NOT NULL DEFAULT 0,
    value integer NOT NULL DEFAULT 0,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}}) NOT NULL,
    superficie_m2 double precision,
    requiere_edicion_manual boolean DEFAULT false,
    motivo_inconsistencia varchar,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.buildingpart (
    gid serial PRIMARY KEY,
    gml_id varchar NOT NULL,
    numberoffloorsaboveground integer NOT NULL DEFAULT 0,
    numberoffloorsbelowground integer NOT NULL DEFAULT 0,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}}) NOT NULL,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.cadastralparcel (
    gid serial PRIMARY KEY,
    gml_id varchar NOT NULL UNIQUE,
    areavalue numeric NOT NULL CHECK (areavalue > 0),
    localid varchar,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}}) NOT NULL,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.tramovial (
    gid serial PRIMARY KEY,
    id_tramo varchar NOT NULL UNIQUE,
    id_vial varchar NOT NULL,
    clased varchar,
    nombre varchar,
    firmed varchar,
    geom geometry(MultiLineString, {{SRID_PROYECTO}}) NOT NULL,
    requiere_edicion_manual boolean DEFAULT false,
    motivo_inconsistencia varchar,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.portalpk (
    gid serial PRIMARY KEY,
    id_tramo varchar NOT NULL,
    id_vial varchar NOT NULL,
    id_porpk varchar NOT NULL UNIQUE,
    numero varchar NOT NULL,
    geom geometry(MultiPoint, {{SRID_PROYECTO}}) NOT NULL,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.tramocurso (
    gid serial PRIMARY KEY,
    id_curso varchar NOT NULL UNIQUE,
    nombre varchar,
    tipo_curso varchar,
    geom geometry(MultiLineString, {{SRID_PROYECTO}}) NOT NULL,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.siose_pol (
    gid serial PRIMARY KEY,
    id_polygon varchar NOT NULL UNIQUE,
    codiige integer NOT NULL,
    hilucs integer NOT NULL,
    geom geometry(MultiPolygon, {{SRID_PROYECTO}}) NOT NULL,
    tipo_error varchar DEFAULT 'Apto',
    corregido varchar DEFAULT 'no aplica'
);

CREATE TABLE jcm3.siose_codiige (
    codiige integer PRIMARY KEY,
    descripcion varchar,
    color_html varchar(7)
);

CREATE TABLE jcm3.siose_hilucs (
    hilucs integer PRIMARY KEY,
    descripcion varchar,
    color_html varchar(7)
);

-- ============================================================================
-- 2.5. CARGA E INICIALIZACIÓN DE DATOS (RESOLVIENDO DUPLICADOS AL VUELO)
-- ============================================================================

INSERT INTO jcm3.municipio (inspireid, natcode, nameunit, geom)
SELECT 
    CASE 
        WHEN inspireid IS NULL THEN 'MISSING_MUN_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY inspireid ORDER BY gid) > 1 THEN inspireid || '_DUP_' || gid
        ELSE inspireid
    END,
    natcode, nameunit, geom
FROM jcm2.municipio;

INSERT INTO jcm3.building (gid, gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom, superficie_m2, tipo_error, corregido)
SELECT 
    gid,
    CASE 
        WHEN gml_id IS NULL THEN 'MISSING_BUILDING_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN gml_id || '_DUP_' || gid
        ELSE gml_id
    END,
    current_use_in, currentuse, numberofbuildingunits, value, geom, ST_Area(geom),
    CASE 
        WHEN gml_id IS NULL THEN 'INSPIRE gml_id nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN 'INSPIRE gml_id duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN gml_id IS NULL OR ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.building;

SELECT setval(pg_get_serial_sequence('jcm3.building', 'gid'), COALESCE(MAX(gid), 1)) FROM jcm3.building;

INSERT INTO jcm3.buildingpart (gid, gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
SELECT bp.gid, COALESCE(bp.gml_id, 'MISSING_BP_' || bp.gid), bp.numberoffloorsaboveground, bp.numberoffloorsbelowground, bp.geom
FROM jcm2.buildingpart bp;

SELECT setval(pg_get_serial_sequence('jcm3.buildingpart', 'gid'), COALESCE(MAX(gid), 1)) FROM jcm3.buildingpart;

INSERT INTO jcm3.cadastralparcel (gml_id, areavalue, localid, geom, tipo_error, corregido)
SELECT 
    CASE 
        WHEN gml_id IS NULL THEN 'MISSING_CP_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN gml_id || '_DUP_' || gid
        ELSE gml_id
    END,
    COALESCE(areavalue, 1.0), localid, geom,
    CASE 
        WHEN gml_id IS NULL THEN 'INSPIRE gml_id nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN 'INSPIRE gml_id duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN gml_id IS NULL OR ROW_NUMBER() OVER (PARTITION BY gml_id ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.cadastralparcel;

INSERT INTO jcm3.tramovial (id_tramo, id_vial, clased, nombre, firmed, geom, tipo_error, corregido)
SELECT 
    CASE 
        WHEN id_tramo IS NULL THEN 'MISSING_TRAMO_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY id_tramo ORDER BY gid) > 1 THEN id_tramo || '_DUP_' || gid
        ELSE id_tramo
    END,
    COALESCE(id_vial, 'MISSING_VIAL_' || gid),
    clased, nombre, firmed, ST_Multi(ST_SnapToGrid(geom, 0.001)),
    CASE 
        WHEN id_tramo IS NULL THEN 'INSPIRE id_tramo nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY id_tramo ORDER BY gid) > 1 THEN 'INSPIRE id_tramo duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN id_tramo IS NULL OR ROW_NUMBER() OVER (PARTITION BY id_tramo ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.tramovial;

INSERT INTO jcm3.portalpk (id_tramo, id_vial, id_porpk, numero, geom, tipo_error, corregido)
SELECT 
    COALESCE(id_tramo, 'MISSING_TRAMO_' || gid),
    COALESCE(id_vial, 'MISSING_VIAL_' || gid),
    CASE 
        WHEN id_porpk IS NULL THEN 'MISSING_PORTAL_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY id_porpk ORDER BY gid) > 1 THEN id_porpk || '_DUP_' || gid
        ELSE id_porpk
    END,
    COALESCE(numero, 'S/N'), geom,
    CASE 
        WHEN id_porpk IS NULL THEN 'INSPIRE id_porpk nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY id_porpk ORDER BY gid) > 1 THEN 'INSPIRE id_porpk duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN id_porpk IS NULL OR ROW_NUMBER() OVER (PARTITION BY id_porpk ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.portalpk;

INSERT INTO jcm3.tramocurso (id_curso, nombre, tipo_curso, geom, tipo_error, corregido)
SELECT 
    CASE 
        WHEN id_curso IS NULL THEN 'MISSING_CURSO_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY id_curso ORDER BY gid) > 1 THEN id_curso || '_DUP_' || gid
        ELSE id_curso
    END,
    nombre, tipo_curso, geom,
    CASE 
        WHEN id_curso IS NULL THEN 'INSPIRE id_curso nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY id_curso ORDER BY gid) > 1 THEN 'INSPIRE id_curso duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN id_curso IS NULL OR ROW_NUMBER() OVER (PARTITION BY id_curso ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.tramocurso;

INSERT INTO jcm3.siose_pol (id_polygon, codiige, hilucs, geom, tipo_error, corregido)
SELECT 
    CASE 
        WHEN id_polygon IS NULL THEN 'MISSING_POLY_' || gid
        WHEN ROW_NUMBER() OVER (PARTITION BY id_polygon ORDER BY gid) > 1 THEN id_polygon || '_DUP_' || gid
        ELSE id_polygon
    END,
    COALESCE(codiige, 999), COALESCE(hilucs, 999), geom,
    CASE 
        WHEN id_polygon IS NULL THEN 'INSPIRE id_polygon nulo'
        WHEN ROW_NUMBER() OVER (PARTITION BY id_polygon ORDER BY gid) > 1 THEN 'INSPIRE id_polygon duplicado'
        ELSE 'Apto'
    END,
    CASE 
        WHEN id_polygon IS NULL OR ROW_NUMBER() OVER (PARTITION BY id_polygon ORDER BY gid) > 1 THEN 'no'
        ELSE 'no aplica'
    END
FROM jcm2.siose_pol;

INSERT INTO jcm3.siose_codiige SELECT * FROM jcm2.siose_codiige;
INSERT INTO jcm3.siose_hilucs SELECT * FROM jcm2.siose_hilucs;

-- Crear índices espaciales
CREATE INDEX ON jcm3.building USING gist(geom);
CREATE INDEX ON jcm3.buildingpart USING gist(geom);
CREATE INDEX ON jcm3.cadastralparcel USING gist(geom);
CREATE INDEX ON jcm3.tramovial USING gist(geom);
CREATE INDEX ON jcm3.portalpk USING gist(geom);
CREATE INDEX ON jcm3.tramocurso USING gist(geom);
CREATE INDEX ON jcm3.siose_pol USING gist(geom);

-- ============================================================================
-- 3. PROCESAMIENTO Y CORRECCIÓN TOPOLÓGICA CON REGISTRO DE TRAZABILIDAD
-- ============================================================================

CREATE TABLE jcm3.vial_edificio_reporte (
    tv_gid integer PRIMARY KEY,
    b_gid integer,
    estado varchar
);

CREATE TABLE jcm3.vial_stubs_reporte (
    tv_gid integer PRIMARY KEY,
    estado varchar
);

-- A. Corrección automática de solapes menores a 0.5 m2 mediante snapping/diferencia
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_solapes_edificios()
RETURNS void AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT b1.gid AS gid1, b2.gid AS gid2
        FROM jcm3.building b1
        JOIN jcm3.building b2 ON b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid
        WHERE ST_Area(ST_Intersection(b1.geom, b2.geom)) < 0.5
    LOOP
        -- Asegurar que siguen solapándose en esta iteración
        IF EXISTS (
            SELECT 1 FROM jcm3.building b1, jcm3.building b2
            WHERE b1.gid = r.gid1 AND b2.gid = r.gid2 AND b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********')
        ) THEN
            UPDATE jcm3.building
            SET geom = ST_Multi(STX_Extract(ST_Difference(geom, (SELECT geom FROM jcm3.building WHERE gid = r.gid1)), 3)),
                tipo_error = 'Building solape con building',
                corregido = 'corregido'
            WHERE gid = r.gid2;

            UPDATE jcm3.building
            SET tipo_error = 'Building solape con building',
                corregido = 'corregido'
            WHERE gid = r.gid1;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- B. Corrección automatizada de intersecciones vial-edificio
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_vial_edificio()
RETURNS void AS $$
DECLARE
    r record;
    line geometry;
    b_geom geometry;
    poly_geom geometry;
    p_start geometry;
    p_end geometry;
    new_geom geometry;
    
    -- Variables Regla 1.2
    int_geom geometry;
    int_len double precision;
    total_area double precision;
    split_coll geometry;
    min_split_area double precision;
    split_part geometry;
    i integer;
    
    -- Variables de desvío
    b_boundary geometry;
    b_buf geometry;
    b_buf_boundary geometry;
    pt_entry geometry;
    pt_exit geometry;
    pt_entry_buf geometry;
    pt_exit_buf geometry;
    detour_frac1 double precision;
    detour_frac2 double precision;
    tmp_frac double precision;
    detour_1 geometry;
    detour_2 geometry;
    detour_chosen geometry;
    detour_len1 double precision;
    detour_len2 double precision;
    intersect_others_1 boolean;
    intersect_others_2 boolean;
    intersect_roads_1 boolean;
    intersect_roads_2 boolean;
    
    -- Variables de reconstrucción
    frac_entry double precision;
    frac_exit double precision;
    tv_start geometry;
    tv_end geometry;
    parts_coll geometry;
    line_part geometry;
BEGIN
    FOR r IN
        SELECT tv.gid AS tv_gid, b.gid AS b_gid, tv.geom AS tv_geom, b.geom AS b_geom
        FROM jcm3.tramovial tv
        JOIN jcm3.building b ON ST_Intersects(tv.geom, b.geom)
    LOOP
        line := ST_GeometryN(r.tv_geom, 1);
        b_geom := r.b_geom;
        p_start := ST_StartPoint(line);
        p_end := ST_EndPoint(line);
        
        -- REGLA 1.1: Vía finaliza en el interior del edificio
        IF (ST_Contains(b_geom, p_start) AND NOT ST_Contains(b_geom, p_end)) OR
           (ST_Contains(b_geom, p_end) AND NOT ST_Contains(b_geom, p_start)) THEN
           
            new_geom := ST_Difference(r.tv_geom, b_geom);
            
            IF ST_Contains(b_geom, p_start) THEN
                FOR line_part IN SELECT (ST_Dump(new_geom)).geom LOOP
                    IF ST_Intersects(line_part, p_end) THEN
                        new_geom := ST_Multi(line_part);
                        EXIT;
                    END IF;
                END LOOP;
            ELSE
                FOR line_part IN SELECT (ST_Dump(new_geom)).geom LOOP
                    IF ST_Intersects(line_part, p_start) THEN
                        new_geom := ST_Multi(line_part);
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
            
            UPDATE jcm3.tramovial 
            SET geom = new_geom,
                tipo_error = 'TramoVia solape building',
                corregido = 'corregido'
            WHERE gid = r.tv_gid;
            
            UPDATE jcm3.building
            SET tipo_error = 'Building solape con tramo vial',
                corregido = 'Tramo Corregido'
            WHERE gid = r.b_gid;
            
            INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
            VALUES (r.tv_gid, r.b_gid, 'Corregido 1.1 (Finaliza dentro)')
            ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
            
        -- REGLA 1.2: Vía atraviesa ligeramente el edificio (cruce menor a 5m y corte < 30%)
        ELSIF NOT ST_Contains(b_geom, p_start) AND NOT ST_Contains(b_geom, p_end) THEN
            int_geom := ST_Intersection(r.tv_geom, b_geom);
            int_len := ST_Length(int_geom);
            
            IF int_len < 5.0 THEN
                total_area := ST_Area(b_geom);
                split_coll := ST_Split(b_geom, r.tv_geom);
                min_split_area := total_area;
                
                FOR i IN 1..ST_NumGeometries(split_coll) LOOP
                    split_part := ST_GeometryN(split_coll, i);
                    IF ST_GeometryType(split_part) LIKE '%Polygon' THEN
                        IF ST_Area(split_part) < min_split_area THEN
                            min_split_area := ST_Area(split_part);
                        END IF;
                    END IF;
                END LOOP;
                
                IF min_split_area < 0.3 * total_area THEN
                    -- Extraer el polígono constituyente que interseca la vía
                    FOR poly_geom IN SELECT (ST_Dump(b_geom)).geom LOOP
                        IF ST_Intersects(poly_geom, line) THEN
                            EXIT;
                        END IF;
                    END LOOP;
                    
                    b_boundary := ST_ExteriorRing(poly_geom);
                    int_geom := ST_Intersection(b_boundary, line);
                    
                    IF ST_NumGeometries(int_geom) = 2 THEN
                        pt_entry := ST_GeometryN(int_geom, 1);
                        pt_exit := ST_GeometryN(int_geom, 2);
                        
                        -- Generar buffer de 5cm y extraer contorno
                        b_buf := ST_GeometryN(ST_Multi(ST_Buffer(poly_geom, 0.05)), 1);
                        b_buf_boundary := ST_ExteriorRing(b_buf);
                        
                        pt_entry_buf := ST_ClosestPoint(b_buf_boundary, pt_entry);
                        pt_exit_buf := ST_ClosestPoint(b_buf_boundary, pt_exit);
                        
                        -- Encontrar posiciones a lo largo de la línea del contorno del buffer
                        detour_frac1 := ST_LineLocatePoint(b_buf_boundary, pt_entry_buf);
                        detour_frac2 := ST_LineLocatePoint(b_buf_boundary, pt_exit_buf);
                        
                        IF detour_frac1 > detour_frac2 THEN
                            tmp_frac := detour_frac1;
                            detour_frac1 := detour_frac2;
                            detour_frac2 := tmp_frac;
                        END IF;
                        
                        -- Desvío 1: ruta directa
                        detour_1 := ST_LineSubstring(b_buf_boundary, detour_frac1, detour_frac2);
                        -- Desvío 2: ruta alternativa rodeando el otro extremo del anillo
                        detour_2 := ST_LineMerge(ST_Union(
                            ST_LineSubstring(b_buf_boundary, detour_frac2, 1),
                            ST_LineSubstring(b_buf_boundary, 0, detour_frac1)
                        ));
                        
                        detour_len1 := ST_Length(detour_1);
                        detour_len2 := ST_Length(detour_2);
                        
                        -- Validar si las rutas intersectan con otras construcciones
                        SELECT EXISTS (
                            SELECT 1 FROM jcm3.building ob
                            WHERE ob.gid <> r.b_gid AND ST_Intersects(ob.geom, detour_1)
                        ) INTO intersect_others_1;
                        
                        SELECT EXISTS (
                            SELECT 1 FROM jcm3.building ob
                            WHERE ob.gid <> r.b_gid AND ST_Intersects(ob.geom, detour_2)
                        ) INTO intersect_others_2;
                        
                        -- Validar si las rutas intersectan el interior de otros tramos viales (evitando cruces sin nodo)
                        SELECT EXISTS (
                            SELECT 1 FROM jcm3.tramovial otv
                            WHERE otv.gid <> r.tv_gid 
                              AND otv.geom && detour_1 
                              AND ST_Intersects(detour_1, otv.geom)
                              AND ST_Relate(detour_1, otv.geom, 'T********')
                        ) INTO intersect_roads_1;
                        
                        SELECT EXISTS (
                            SELECT 1 FROM jcm3.tramovial otv
                            WHERE otv.gid <> r.tv_gid 
                              AND otv.geom && detour_2 
                              AND ST_Intersects(detour_2, otv.geom)
                              AND ST_Relate(detour_2, otv.geom, 'T********')
                        ) INTO intersect_roads_2;
                        
                        detour_chosen := NULL;
                        IF NOT intersect_others_1 AND NOT intersect_roads_1 AND NOT intersect_others_2 AND NOT intersect_roads_2 THEN
                            IF detour_len1 < detour_len2 THEN
                                detour_chosen := detour_1;
                            ELSE
                                detour_chosen := detour_2;
                            END IF;
                        ELSIF NOT intersect_others_1 AND NOT intersect_roads_1 THEN
                            detour_chosen := detour_1;
                        ELSIF NOT intersect_others_2 AND NOT intersect_roads_2 THEN
                            detour_chosen := detour_2;
                        END IF;
                        
                        IF detour_chosen IS NOT NULL THEN
                            -- Extraer fracciones en la línea original
                            frac_entry := ST_LineLocatePoint(line, pt_entry);
                            frac_exit := ST_LineLocatePoint(line, pt_exit);
                            
                            IF frac_entry > frac_exit THEN
                                tmp_frac := frac_entry;
                                frac_entry := frac_exit;
                                frac_exit := tmp_frac;
                            END IF;
                            
                            tv_start := ST_LineSubstring(line, 0, frac_entry);
                            tv_end := ST_LineSubstring(line, frac_exit, 1);
                            
                            parts_coll := ST_Collect(ARRAY[
                                tv_start,
                                ST_MakeLine(pt_entry, pt_entry_buf),
                                detour_chosen,
                                ST_MakeLine(pt_exit_buf, pt_exit),
                                tv_end
                            ]);
                            
                            -- Consolidar geometría con snapping a rejilla milimétrica
                            new_geom := ST_LineMerge(ST_SnapToGrid(parts_coll, 0.001));
                            
                            UPDATE jcm3.tramovial 
                            SET geom = ST_Multi(new_geom),
                                tipo_error = 'TramoVia solape building',
                                corregido = 'corregido'
                            WHERE gid = r.tv_gid;
                            
                            UPDATE jcm3.building
                            SET tipo_error = 'Building solape con tramo vial',
                                corregido = 'Tramo Corregido'
                            WHERE gid = r.b_gid;
                            
                            INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
                            VALUES (r.tv_gid, r.b_gid, 'Corregido 1.2 (Bordeado)')
                            ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
                        ELSE
                            INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
                            VALUES (r.tv_gid, r.b_gid, 'No Resuelto 1.2 (Sin desvío libre)')
                            ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
                        END IF;
                    ELSE
                        INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
                        VALUES (r.tv_gid, r.b_gid, 'No Resuelto 1.2 (Cruce complejo)')
                        ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
                    END IF;
                ELSE
                    INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
                    VALUES (r.tv_gid, r.b_gid, 'No Resuelto 1.2 (Corte de área >= 30%)')
                    ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
                END IF;
            ELSE
                INSERT INTO jcm3.vial_edificio_reporte (tv_gid, b_gid, estado)
                VALUES (r.tv_gid, r.b_gid, 'No Resuelto (Intersección >= 5m)')
                ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado, b_gid = EXCLUDED.b_gid;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- C. Corrección automatizada de stubs / solapes por escala en cruces
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_stubs()
RETURNS void AS $$
DECLARE
    r record;
    line1 geometry;
    line2 geometry;
    pt geometry;
    frac_p1 double precision;
    frac_p2 double precision;
    sub_a geometry;
    sub_b geometry;
    has_continuity_a boolean;
    has_continuity_b boolean;
    current_geom1 geometry;
    current_geom2 geometry;
BEGIN
    FOR r IN
        SELECT 
            tv1.gid AS tv1_gid,
            tv2.gid AS tv2_gid,
            (ST_Dump(ST_Intersection(tv1.geom, tv2.geom))).geom AS pt
        FROM jcm3.tramovial tv1
        JOIN jcm3.tramovial tv2 ON ST_Intersects(tv1.geom, tv2.geom) AND tv1.gid < tv2.gid
        WHERE ST_Relate(tv1.geom, tv2.geom, '0********')
    LOOP
        pt := r.pt;
        
        -- Obtener geometrías actualizadas
        SELECT geom INTO current_geom1 FROM jcm3.tramovial WHERE gid = r.tv1_gid;
        SELECT geom INTO current_geom2 FROM jcm3.tramovial WHERE gid = r.tv2_gid;
        
        IF current_geom1 IS NULL OR current_geom2 IS NULL THEN
            CONTINUE;
        END IF;
        
        line1 := ST_GeometryN(current_geom1, 1);
        line2 := ST_GeometryN(current_geom2, 1);
        
        -- Verificar si siguen intersectándose en el interior
        IF NOT ST_Relate(current_geom1, current_geom2, '0********') THEN
            CONTINUE;
        END IF;
        
        -- 1. CORREGIR STUBS EN TV1
        frac_p1 := ST_LineLocatePoint(line1, pt);
        IF frac_p1 > 0.0 AND frac_p1 < 1.0 THEN
            sub_a := ST_LineSubstring(line1, 0, frac_p1);
            sub_b := ST_LineSubstring(line1, frac_p1, 1);
            
            -- Evaluar segmento sub_a (extremo inicial de tv1)
            IF ST_Length(sub_a) < 1.0 AND ST_Length(sub_a) > 0.0 THEN
                SELECT EXISTS (
                    SELECT 1 FROM jcm3.tramovial tv
                    WHERE tv.gid <> r.tv1_gid AND tv.gid <> r.tv2_gid
                      AND ST_DWithin(tv.geom, ST_StartPoint(sub_a), 0.001)
                ) INTO has_continuity_a;
                
                IF NOT has_continuity_a THEN
                    UPDATE jcm3.tramovial 
                    SET geom = ST_Multi(sub_b),
                        tipo_error = 'TramoVia stub',
                        corregido = 'corregido'
                    WHERE gid = r.tv1_gid;
                    
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Stub Eliminado')
                    ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                    
                    -- Actualizar line1 para el siguiente paso en este mismo bucle
                    line1 := sub_b;
                ELSE
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                    ON CONFLICT (tv_gid) DO NOTHING;
                END IF;
            END IF;
            
            -- Evaluar segmento sub_b (extremo final de tv1)
            frac_p1 := ST_LineLocatePoint(line1, pt);
            IF frac_p1 > 0.0 AND frac_p1 < 1.0 THEN
                sub_a := ST_LineSubstring(line1, 0, frac_p1);
                sub_b := ST_LineSubstring(line1, frac_p1, 1);
                
                IF ST_Length(sub_b) < 1.0 AND ST_Length(sub_b) > 0.0 THEN
                    SELECT EXISTS (
                        SELECT 1 FROM jcm3.tramovial tv
                        WHERE tv.gid <> r.tv1_gid AND tv.gid <> r.tv2_gid
                          AND ST_DWithin(tv.geom, ST_EndPoint(sub_b), 0.001)
                    ) INTO has_continuity_b;
                    
                    IF NOT has_continuity_b THEN
                        UPDATE jcm3.tramovial 
                        SET geom = ST_Multi(sub_a),
                            tipo_error = 'TramoVia stub',
                            corregido = 'corregido'
                        WHERE gid = r.tv1_gid;
                        
                        INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                        VALUES (r.tv1_gid, 'Stub Eliminado')
                        ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                        
                        line1 := sub_a;
                    ELSE
                        INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                        VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                        ON CONFLICT (tv_gid) DO NOTHING;
                    END IF;
                END IF;
            END IF;
        END IF;
        
        -- 2. CORREGIR STUBS EN TV2
        -- Volver a comprobar la relación porque tv1 ya se pudo haber modificado
        IF ST_Relate(ST_Multi(line1), current_geom2, '0********') THEN
            frac_p2 := ST_LineLocatePoint(line2, pt);
            IF frac_p2 > 0.0 AND frac_p2 < 1.0 THEN
                sub_a := ST_LineSubstring(line2, 0, frac_p2);
                sub_b := ST_LineSubstring(line2, frac_p2, 1);
                
                -- Evaluar segmento sub_a (extremo inicial de tv2)
                IF ST_Length(sub_a) < 1.0 AND ST_Length(sub_a) > 0.0 THEN
                    SELECT EXISTS (
                        SELECT 1 FROM jcm3.tramovial tv
                        WHERE tv.gid <> r.tv1_gid AND tv.gid <> r.tv2_gid
                          AND ST_DWithin(tv.geom, ST_StartPoint(sub_a), 0.001)
                    ) INTO has_continuity_a;
                    
                    IF NOT has_continuity_a THEN
                        UPDATE jcm3.tramovial 
                        SET geom = ST_Multi(sub_b),
                            tipo_error = 'TramoVia stub',
                            corregido = 'corregido'
                        WHERE gid = r.tv2_gid;
                        
                        INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                        VALUES (r.tv2_gid, 'Stub Eliminado')
                        ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                        
                        line2 := sub_b;
                    ELSE
                        INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                        VALUES (r.tv2_gid, 'Calle Cerrada Válida')
                        ON CONFLICT (tv_gid) DO NOTHING;
                    END IF;
                END IF;
                
                -- Evaluar segmento sub_b (extremo final de tv2)
                frac_p2 := ST_LineLocatePoint(line2, pt);
                IF frac_p2 > 0.0 AND frac_p2 < 1.0 THEN
                    sub_a := ST_LineSubstring(line2, 0, frac_p2);
                    sub_b := ST_LineSubstring(line2, frac_p2, 1);
                    
                    IF ST_Length(sub_b) < 1.0 AND ST_Length(sub_b) > 0.0 THEN
                        SELECT EXISTS (
                            SELECT 1 FROM jcm3.tramovial tv
                            WHERE tv.gid <> r.tv1_gid AND tv.gid <> r.tv2_gid
                              AND ST_DWithin(tv.geom, ST_EndPoint(sub_b), 0.001)
                        ) INTO has_continuity_b;
                        
                        IF NOT has_continuity_b THEN
                            UPDATE jcm3.tramovial 
                            SET geom = ST_Multi(sub_a),
                                tipo_error = 'TramoVia stub',
                                corregido = 'corregido'
                            WHERE gid = r.tv2_gid;
                            
                            INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                            VALUES (r.tv2_gid, 'Stub Eliminado')
                            ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                        ELSE
                            INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                            VALUES (r.tv2_gid, 'Calle Cerrada Válida')
                            ON CONFLICT (tv_gid) DO NOTHING;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- D. Corrección de BuildingParts que sobresalen de su Building padre (unir para contener)
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_buildingpart_sin_building()
RETURNS void AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT bp.gid AS bp_gid, b.gid AS b_gid, bp.geom AS bp_geom
        FROM jcm3.buildingpart bp
        JOIN jcm3.building b ON SPLIT_PART(bp.gml_id, '_part', 1) = b.gml_id
        WHERE NOT (b.geom && bp.geom AND ST_Contains(b.geom, bp.geom))
    LOOP
        -- Expandir la geometría del Building padre para contener a la parte
        UPDATE jcm3.building
        SET geom = ST_Multi(STX_Extract(ST_Union(geom, r.bp_geom), 3)),
            tipo_error = 'Building expandido por BuildingPart',
            corregido = 'corregido'
        WHERE gid = r.b_gid;

        UPDATE jcm3.buildingpart
        SET tipo_error = 'BuildingPart corregido (contenido en padre)',
            corregido = 'corregido'
        WHERE gid = r.bp_gid;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EJECUCIÓN ORDENADA DE LAS FUNCIONES DE CORRECCIÓN AUTOMÁTICA
-- ============================================================================
-- Primero, expandimos los edificios para contener sus partes (cambia las geometrías de los edificios)
SELECT jcm3.fn_corregir_buildingpart_sin_building();

-- Segundo, corregimos los solapes espaciales entre los edificios (incluyendo los expandidos)
SELECT jcm3.fn_corregir_solapes_edificios();

-- Tercero, corregimos las intersecciones de viales y edificios
SELECT jcm3.fn_corregir_vial_edificio();

-- Cuarto, corregimos los stubs viales
SELECT jcm3.fn_corregir_stubs();

-- ============================================================================
-- 3.8. MARCAR ERRORES PERSISTENTES NO RESUELTOS EN JCM3
-- ============================================================================

-- 1. Marcar intersecciones vial-edificio no resueltas en viales y edificios
UPDATE jcm3.tramovial tv
SET requiere_edicion_manual = true,
    motivo_inconsistencia = COALESCE(tv.motivo_inconsistencia || '; ', '') || 'Intersección edificación (' || r.estado || ' con ' || b.gml_id || ')',
    tipo_error = 'TramoVia solape building',
    corregido = 'no'
FROM jcm3.vial_edificio_reporte r
JOIN jcm3.building b ON r.b_gid = b.gid
WHERE tv.gid = r.tv_gid AND r.estado LIKE 'No Resuelto%';

UPDATE jcm3.building b
SET requiere_edicion_manual = true,
    motivo_inconsistencia = COALESCE(b.motivo_inconsistencia || '; ', '') || 'Intersección tramo vial (' || r.estado || ' con ' || tv.id_tramo || ')',
    tipo_error = 'Building solape con tramo vial',
    corregido = 'no'
FROM jcm3.vial_edificio_reporte r
JOIN jcm3.tramovial tv ON r.tv_gid = tv.gid
WHERE b.gid = r.b_gid AND r.estado LIKE 'No Resuelto%';

-- 2. Marcar cruces viales sin nodos en viales
WITH cruces_sin_nodos AS (
    SELECT DISTINCT tv1.gid
    FROM jcm3.tramovial tv1
    JOIN jcm3.tramovial tv2 ON ST_Intersects(tv1.geom, tv2.geom) AND tv1.gid <> tv2.gid
    WHERE ST_Relate(tv1.geom, tv2.geom, '0********')
)
UPDATE jcm3.tramovial tv
SET requiere_edicion_manual = true,
    motivo_inconsistencia = COALESCE(tv.motivo_inconsistencia || '; ', '') || 'Cruce sin nodo con tramo/s: ' || (
        SELECT string_agg(tv2.id_tramo, ', ')
        FROM jcm3.tramovial tv2
        WHERE ST_Intersects(tv.geom, tv2.geom) AND tv.gid <> tv2.gid
          AND ST_Relate(tv.geom, tv2.geom, '0********')
    ),
    tipo_error = 'TramoVia cruce sin nodo',
    corregido = 'no'
WHERE gid IN (SELECT gid FROM cruces_sin_nodos);

-- 3. Marcar solapes de edificios no resueltos (>= 0.5 m2)
WITH solapes_restantes AS (
    SELECT DISTINCT b1.gid
    FROM jcm3.building b1
    JOIN jcm3.building b2 ON b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid <> b2.gid
    WHERE ST_Area(ST_Intersection(b1.geom, b2.geom)) >= 0.5
)
UPDATE jcm3.building b
SET requiere_edicion_manual = true,
    motivo_inconsistencia = COALESCE(b.motivo_inconsistencia || '; ', '') || 'Solape con edificación/es: ' || (
        SELECT string_agg(b2.gml_id, ', ')
        FROM jcm3.building b2
        WHERE b.geom && b2.geom AND ST_Relate(b.geom, b2.geom, '2********') AND b.gid <> b2.gid
    ),
    tipo_error = 'Building solape con building',
    corregido = 'no'
WHERE gid IN (SELECT gid FROM solapes_restantes)
  AND corregido <> 'corregido';

-- 5. Marcar BuildingPart no contenidos en Building padre persistentes
WITH bp_sin_building AS (
    SELECT bp.gid
    FROM jcm3.buildingpart bp
    JOIN jcm3.building b ON SPLIT_PART(bp.gml_id, '_part', 1) = b.gml_id
    WHERE NOT (b.geom && bp.geom AND ST_Contains(b.geom, bp.geom))
)
UPDATE jcm3.buildingpart bp
SET tipo_error = 'BuildingPart no contenido en padre',
    corregido = 'no'
WHERE gid IN (SELECT gid FROM bp_sin_building)
  AND corregido <> 'corregido';

-- 6. Marcar BuildingPart huérfanos
WITH bp_huerfanos AS (
    SELECT bp.gid
    FROM jcm3.buildingpart bp
    WHERE NOT EXISTS (
        SELECT 1 FROM jcm3.building b WHERE b.gml_id = SPLIT_PART(bp.gml_id, '_part', 1)
    )
)
UPDATE jcm3.buildingpart bp
SET tipo_error = 'BuildingPart huérfano (sin padre)',
    corregido = 'no'
WHERE gid IN (SELECT gid FROM bp_huerfanos)
  AND corregido <> 'corregido';

-- ============================================================================
-- 3.9. VISTAS DE DETALLE PARA INCONSISTENCIAS Y REGLAS (JCM3)
-- ============================================================================

CREATE OR REPLACE VIEW jcm3.view_vial_edificio_intersecciones AS
SELECT 
    row_number() OVER () AS gid,
    b.gid AS building_gid,
    tv.gid AS tramovial_gid,
    b.gml_id AS building_gml_id,
    tv.id_tramo AS tramovial_id,
    ST_Length(inter.geom_linea) AS longitud,
    COALESCE(r.estado, 'Sin Error') AS estado,
    ST_Multi(inter.geom_linea)::geometry(MultiLineString, {{SRID_PROYECTO}}) AS geom
FROM jcm3.building b
JOIN jcm3.tramovial tv ON b.geom && tv.geom AND ST_Relate(b.geom, tv.geom, '1********')
LEFT JOIN jcm3.vial_edificio_reporte r ON r.tv_gid = tv.gid AND r.b_gid = b.gid
CROSS JOIN LATERAL (
    SELECT STX_Extract(ST_Intersection(b.geom, tv.geom), 2) AS geom_linea
) inter
WHERE inter.geom_linea IS NOT NULL;

CREATE OR REPLACE VIEW jcm3.view_vial_edificio_corregidos AS
SELECT * FROM jcm3.view_vial_edificio_intersecciones
WHERE estado LIKE 'Corregido%';

CREATE OR REPLACE VIEW jcm3.view_vial_edificio_no_resueltos AS
SELECT * FROM jcm3.view_vial_edificio_intersecciones
WHERE estado LIKE 'No Resuelto%';

CREATE OR REPLACE VIEW jcm3.view_cruces_viales_puntos_baseline AS
SELECT (row_number() OVER ()::integer) AS gid,
       q.tramovial_gid1, q.tramovial_gid2,
       q.tramovial_id1, q.tramovial_id2,
       q.geom
FROM (
    SELECT tv1.gid AS tramovial_gid1, tv2.gid AS tramovial_gid2,
           tv1.id_tramo AS tramovial_id1, tv2.id_tramo AS tramovial_id2,
           (ST_Dump(ST_Multi(inter.geom_punto))).geom::geometry(Point, {{SRID_PROYECTO}}) AS geom
    FROM jcm2.tramovial tv1
    JOIN jcm2.tramovial tv2 ON tv1.geom && tv2.geom AND ST_Relate(tv1.geom, tv2.geom, '0********') AND tv1.gid < tv2.gid
    CROSS JOIN LATERAL (
        SELECT STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1) AS geom_punto
    ) inter
) q;

CREATE OR REPLACE VIEW jcm3.view_cruces_viales_puntos AS
SELECT (row_number() OVER ()::integer) AS gid,
       q.tramovial_gid1, q.tramovial_gid2,
       q.tramovial_id1, q.tramovial_id2,
       q.geom
FROM (
    SELECT tv1.gid AS tramovial_gid1, tv2.gid AS tramovial_gid2,
           tv1.id_tramo AS tramovial_id1, tv2.id_tramo AS tramovial_id2,
           (ST_Dump(ST_Multi(inter.geom_punto))).geom::geometry(Point, {{SRID_PROYECTO}}) AS geom
    FROM jcm3.tramovial tv1
    JOIN jcm3.tramovial tv2 ON tv1.geom && tv2.geom AND ST_Relate(tv1.geom, tv2.geom, '0********') AND tv1.gid < tv2.gid
    CROSS JOIN LATERAL (
        SELECT STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1) AS geom_punto
    ) inter
) q;

CREATE TABLE jcm3.building_solapes_alfanumerica AS
SELECT 
    b1.gid AS gid1, 
    b2.gid AS gid2, 
    b1.gml_id AS gml_id1, 
    b2.gml_id AS gml_id2
FROM jcm3.building b1, jcm3.building b2
WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid;

CREATE OR REPLACE VIEW jcm3.view_building_solapes_agrupada AS
SELECT 
    b1.gid AS gid, 
    count(b2.gid) AS nsolapes,
    array_agg(b2.gid)::varchar AS listasolapes, 
    b1.geom AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid <> b2.gid
GROUP BY b1.gid;

CREATE OR REPLACE VIEW jcm3.view_building_solapes_agrupada_1m2 AS
SELECT 
    b1.gid AS gid, 
    count(b2.gid) AS nsolapes,
    array_agg(b2.gid)::varchar AS listasolapes, 
    b1.geom AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid <> b2.gid
  AND ST_Area(ST_Intersection(b1.geom, b2.geom)) > 1.0
GROUP BY b1.gid;

CREATE OR REPLACE VIEW jcm3.view_building_solapes_intersecciones AS
SELECT 
    row_number() OVER () AS gid,
    b1.gid AS building_gid1, 
    b2.gid AS building_gid2,
    ST_Area(ST_Intersection(b1.geom, b2.geom)) AS area_solape,
    ST_Multi(STX_Extract(ST_Intersection(b1.geom, b2.geom), 3))::geometry(MultiPolygon, {{SRID_PROYECTO}}) AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid;

-- ============================================================================
-- 3.9.5. TABLA RESUMEN DE TRAZABILIDAD (MÉTRICAS UNIFICADAS)
-- ============================================================================

CREATE OR REPLACE VIEW jcm3.view_reporte_resumen_calidad AS
SELECT 'building'::varchar AS capa, tipo_error, corregido, COUNT(*)::integer AS total_elementos
FROM jcm3.building GROUP BY tipo_error, corregido
UNION ALL
SELECT 'tramovial'::varchar, tipo_error, corregido, COUNT(*)::integer
FROM jcm3.tramovial GROUP BY tipo_error, corregido
UNION ALL
SELECT 'cadastralparcel'::varchar, tipo_error, corregido, COUNT(*)::integer
FROM jcm3.cadastralparcel GROUP BY tipo_error, corregido
UNION ALL
SELECT 'portalpk'::varchar, tipo_error, corregido, COUNT(*)::integer
FROM jcm3.portalpk GROUP BY tipo_error, corregido
UNION ALL
SELECT 'tramocurso'::varchar, tipo_error, corregido, COUNT(*)::integer
FROM jcm3.tramocurso GROUP BY tipo_error, corregido
UNION ALL
SELECT 'siose_pol'::varchar, tipo_error, corregido, COUNT(*)::integer
FROM jcm3.siose_pol GROUP BY tipo_error, corregido;

CREATE OR REPLACE VIEW jcm3.view_resumen_calidad_antes_despues AS
SELECT 
    '1. Edificios ID nulo/duplicado'::varchar AS control_calidad,
    (SELECT COUNT(*) FROM jcm3.view_diag_inspire_edificios)::integer AS inconsistencias_jcm2,
    0::integer AS inconsistencias_jcm3
UNION ALL
SELECT 
    '2. Vías ID nulo/duplicado'::varchar,
    (SELECT COUNT(*) FROM jcm3.view_diag_inspire_viales)::integer,
    0::integer
UNION ALL
SELECT 
    '3. Solapes entre edificios'::varchar,
    (SELECT COUNT(*) FROM (SELECT 1 FROM jcm2.building b1, jcm2.building b2 WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid) q)::integer,
    (SELECT COUNT(*) FROM (SELECT 1 FROM jcm3.building b1, jcm3.building b2 WHERE b1.geom && b2.geom AND ST_Relate(b1.geom, b2.geom, '2********') AND b1.gid < b2.gid AND ST_Area(ST_Intersection(b1.geom, b2.geom)) > 0.01) q)::integer
UNION ALL
SELECT 
    '4. Solape lineal vial-edificio'::varchar,
    (SELECT COUNT(DISTINCT tv.gid) FROM jcm2.tramovial tv JOIN jcm2.building b ON tv.geom && b.geom AND ST_Relate(tv.geom, b.geom, '1********'))::integer,
    (SELECT COUNT(DISTINCT tv.gid) FROM jcm3.tramovial tv JOIN jcm3.building b ON tv.geom && b.geom AND ST_Relate(tv.geom, b.geom, '1********'))::integer
UNION ALL
SELECT 
    '5. Cruces viales sin nodo'::varchar,
    (SELECT COUNT(*) FROM jcm3.view_cruces_viales_puntos_baseline)::integer,
    (SELECT COUNT(*) FROM jcm3.view_cruces_viales_puntos)::integer
UNION ALL
SELECT 
    '6. BuildingPart fuera de Building'::varchar,
    (SELECT COUNT(*) FROM jcm3.view_diag_buildingpart_sin_building)::integer,
    (SELECT COUNT(*) FROM jcm3.buildingpart bp JOIN jcm3.building b ON SPLIT_PART(bp.gml_id, '_part', 1) = b.gml_id WHERE NOT (b.geom && bp.geom AND ST_Contains(ST_Buffer(b.geom, 0.01), bp.geom)))::integer
UNION ALL
SELECT 
    '7. BuildingPart huérfano'::varchar,
    (SELECT COUNT(*) FROM jcm3.view_diag_buildingpart_huerfano)::integer,
    (SELECT COUNT(*) FROM jcm3.buildingpart bp WHERE NOT EXISTS (SELECT 1 FROM jcm3.building b WHERE b.gml_id = SPLIT_PART(bp.gml_id, '_part', 1)))::integer;

-- ============================================================================
-- 4. CONSULTAS ANALÍTICAS ESPACIALES CORREGIDAS (SECCIÓN 8)
-- ============================================================================

-- 8.1.1. ¿Cuántas parcelas tienen algún edificio en su interior?
CREATE OR REPLACE VIEW jcm3.view_q8_1_1 AS
SELECT COUNT(*) AS total_parcelas_con_edificios
FROM jcm3.cadastralparcel cp
WHERE EXISTS (
    SELECT 1 
    FROM jcm3.building b 
    WHERE ST_Intersects(cp.geom, b.geom)
);

-- 8.1.2. ¿Cuántas parcelas no tienen ningún edificio en su interior (sin GROUP BY)?
CREATE OR REPLACE VIEW jcm3.view_q8_1_2 AS
SELECT COUNT(*) AS total_parcelas_vacias
FROM jcm3.cadastralparcel cp
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm3.building b 
    WHERE ST_Intersects(cp.geom, b.geom)
);

-- 8.1.3. ¿Cuál es la referencia catastral (gml_id) de la parcela que tiene más edificios en su interior?
CREATE OR REPLACE VIEW jcm3.view_q8_1_3 AS
SELECT cp.gml_id, COUNT(b.gid) AS num_edificios
FROM jcm3.cadastralparcel cp
JOIN jcm3.building b ON ST_Intersects(cp.geom, b.geom)
GROUP BY cp.gml_id, cp.gid
ORDER BY num_edificios DESC, cp.gml_id ASC
LIMIT 1;

-- 8.2. ¿Cuántos edificios aislados (sin otros edificios en 100m) hay?
CREATE OR REPLACE VIEW jcm3.view_q8_2 AS
SELECT COUNT(*) AS total_edificios_aislados
FROM jcm3.building b1
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm3.building b2 
    WHERE b1.gid <> b2.gid 
      AND ST_DWithin(b1.geom, b2.geom, 100));

CREATE OR REPLACE VIEW jcm3.view_q8_3 AS
SELECT 
    s.codiige,
    c.descripcion AS suelo_descripcion,
    ROUND(SUM(ST_Area(ST_Intersection(b.geom, s.geom)))::numeric, 2) AS area_edificada_m2
FROM jcm3.building b
JOIN jcm3.siose_pol s ON ST_Intersects(b.geom, s.geom) AND NOT ST_Touches(b.geom, s.geom)
LEFT JOIN jcm3.siose_codiige c ON s.codiige = c.codiige
GROUP BY s.codiige, c.descripcion
ORDER BY area_edificada_m2 DESC
LIMIT 5;

-- 8.4. Edificios y volumen de sótanos (Floors below ground x Area x 2.5) usando left(bp.gml_id, 25)
CREATE OR REPLACE VIEW jcm3.view_q8_4 AS
SELECT 
    b.gml_id AS building_gml_id,
    ROUND(SUM(ST_Area(bp.geom) * bp.numberoffloorsbelowground * 2.5)::numeric, 2) AS volumen_sotanos_m3
FROM jcm3.building b
JOIN jcm3.buildingpart bp ON SPLIT_PART(bp.gml_id, '_part', 1) = b.gml_id
WHERE bp.numberoffloorsbelowground > 0
GROUP BY b.gml_id, b.gid
ORDER BY volumen_sotanos_m3 DESC
LIMIT 5;

-- 8.5. Consultas propuestas por el estudiante:
-- Consulta 1: Número de edificios situados en zona de potencial inundación (a menos de 50 metros de un río/arroyo)
CREATE OR REPLACE VIEW jcm3.view_q8_5_1 AS
SELECT COUNT(DISTINCT b.gid) AS total_edificios_riesgo_inundacion
FROM jcm3.building b
JOIN jcm3.tramocurso tc ON ST_DWithin(b.geom, tc.geom, 50);

-- Consulta 2: Densidad edificada urbana: top 5 polígonos SIOSE urbanos de Estepona con mayor porcentaje edificado
CREATE OR REPLACE VIEW jcm3.view_q8_5_2 AS
SELECT 
    s.gid AS siose_gid,
    s.codiige,
    c.descripcion AS suelo_descripcion,
    ROUND(ST_Area(s.geom)::numeric, 2) AS area_suelo_m2,
    ROUND(SUM(ST_Area(ST_Intersection(b.geom, s.geom)))::numeric, 2) AS area_edificada_m2,
    ROUND((SUM(ST_Area(ST_Intersection(b.geom, s.geom))) / ST_Area(s.geom) * 100)::numeric, 2) AS porcentaje_edificado
FROM jcm3.siose_pol s
JOIN jcm3.siose_codiige c ON s.codiige = c.codiige
JOIN jcm3.building b ON ST_Intersects(b.geom, s.geom)
WHERE c.descripcion IN ('Casco', 'Ensanche', 'Discontinuo', 'Industrial', 'Servicio dotacional')
GROUP BY s.gid, s.codiige, c.descripcion
HAVING ST_Area(s.geom) > 0
ORDER BY porcentaje_edificado DESC
LIMIT 5;


-- ============================================================================
-- 5. EJERCICIO DE ANÁLISIS ESPACIAL MULTICRITERIO CORREGIDO (SECCIÓN 9)
-- ============================================================================
CREATE OR REPLACE VIEW jcm3.view_analisis_c1_area_vacias AS
SELECT cp.gid, cp.gml_id, cp.localid, cp.areavalue, cp.geom
FROM jcm3.cadastralparcel cp
WHERE cp.areavalue > 1500
  AND NOT EXISTS (
      SELECT 1 
      FROM jcm3.building b 
      WHERE ST_Intersects(cp.geom, b.geom)
  );

CREATE OR REPLACE VIEW jcm3.view_analisis_c2_acceso AS
SELECT cp.gid, cp.gml_id, cp.geom
FROM jcm3.cadastralparcel cp
WHERE EXISTS (
    SELECT 1 
    FROM jcm3.tramovial tv 
    WHERE ST_DWithin(cp.geom, tv.geom, 10) 
      AND tv.firmed = 'Pavimentado'
);

CREATE OR REPLACE VIEW jcm3.view_analisis_c3_inundacion AS
SELECT cp.gid, cp.gml_id, cp.geom
FROM jcm3.cadastralparcel cp
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm3.tramocurso tc 
    WHERE ST_DWithin(cp.geom, tc.geom, 100)
);

CREATE OR REPLACE VIEW jcm3.view_analisis_c4_urbano AS
SELECT DISTINCT cp.gid, cp.gml_id, cp.geom
FROM jcm3.cadastralparcel cp
JOIN jcm3.siose_pol s ON ST_Intersects(cp.geom, s.geom)
WHERE s.codiige BETWEEN 111 AND 140;

CREATE OR REPLACE VIEW jcm3.view_analisis_c5_portales AS
SELECT cp.gid, cp.gml_id, cp.geom
FROM jcm3.cadastralparcel cp
WHERE (
    SELECT COUNT(*) 
    FROM jcm3.portalpk pk 
    WHERE ST_DWithin(cp.geom, pk.geom, 300)
) >= 10;

CREATE OR REPLACE VIEW jcm3.view_parcelas_candidatas_centro AS
SELECT 
    c1.gid,
    c1.gml_id AS parcela_gml_id,
    c1.localid AS parcela_localid,
    ROUND(c1.areavalue::numeric, 2) AS area_parcela_m2,
    c1.geom
FROM jcm3.view_analisis_c1_area_vacias c1
JOIN jcm3.view_analisis_c2_acceso c2 ON c1.gid = c2.gid
JOIN jcm3.view_analisis_c3_inundacion c3 ON c1.gid = c3.gid
JOIN jcm3.view_analisis_c4_urbano c4 ON c1.gid = c4.gid
JOIN jcm3.view_analisis_c5_portales c5 ON c1.gid = c5.gid;

-- ============================================================================
-- 6. AUTOMATIZACIÓN MEDIANTE TRIGGERS EN TABLAS DE jcm2 (SECCIÓN 10)
-- ============================================================================

-- 10.1. Modificación de tabla building y trigger de actualización de área automática
ALTER TABLE jcm2.building ADD COLUMN IF NOT EXISTS superficie_m2 double precision;

CREATE OR REPLACE FUNCTION jcm2.fn_actualizar_area()
RETURNS trigger AS $$
BEGIN
    NEW.superficie_m2 := ST_Area(NEW.geom);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_actualizar_area ON jcm2.building;
CREATE TRIGGER trg_actualizar_area
BEFORE INSERT OR UPDATE OF geom ON jcm2.building
FOR EACH ROW
EXECUTE FUNCTION jcm2.fn_actualizar_area();

-- Recalcular el área para los registros existentes en jcm2
UPDATE jcm2.building SET geom = geom;

-- 10.2. Trigger de validación de condiciones espaciales: Evitar solapes de edificios
CREATE OR REPLACE FUNCTION jcm2.fn_validar_solape()
RETURNS trigger AS $$
DECLARE
    v_overlap_count integer;
BEGIN
    SELECT COUNT(*)
    INTO v_overlap_count
    FROM jcm2.building b
    WHERE (NEW.gid IS NULL OR b.gid <> NEW.gid)
      AND ST_Intersects(NEW.geom, b.geom)
      AND ST_Area(ST_Intersection(NEW.geom, b.geom)) > 1.0;
      
    IF v_overlap_count > 0 THEN
        RAISE EXCEPTION 'ERROR DE INTEGRIDAD TOPOLÓGICA (SERVER-SIDE): El edificio que intenta insertar o modificar solapa espacialmente con otro edificio en más de 1.0 m2.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_solape ON jcm2.building;
CREATE TRIGGER trg_validar_solape
BEFORE INSERT OR UPDATE OF geom ON jcm2.building
FOR EACH ROW
EXECUTE FUNCTION jcm2.fn_validar_solape();

-- ============================================================================
-- 7. DISPARADORES DE CORRECCIÓN MANUAL (QA/QC FEEDBACK LOOP EN JCM3)
-- ============================================================================

-- A. Trigger para jcm3.building
CREATE OR REPLACE FUNCTION jcm3.fn_detectar_correccion_manual_building()
RETURNS trigger AS $$
DECLARE
    v_overlap_count integer;
    v_road_intersect_count integer;
BEGIN
    IF OLD.corregido = 'no' THEN
        -- 1. Verificar si sigue solapándose con otros edificios en más de 1.0 m2
        IF OLD.tipo_error = 'Building solape con building' THEN
            SELECT COUNT(*) INTO v_overlap_count
            FROM jcm3.building b
            WHERE b.gid <> NEW.gid
              AND ST_Intersects(NEW.geom, b.geom)
              AND ST_Area(ST_Intersection(NEW.geom, b.geom)) > 1.0;
              
            IF v_overlap_count = 0 THEN
                NEW.corregido := 'manual';
                NEW.requiere_edicion_manual := false;
                NEW.motivo_inconsistencia := NULL;
            END IF;
        END IF;

        -- 2. Verificar si sigue solapándose con vías (si ese era su error)
        IF OLD.tipo_error = 'Building solape con tramo vial' THEN
            SELECT COUNT(*) INTO v_road_intersect_count
            FROM jcm3.tramovial tv
            WHERE ST_Intersects(NEW.geom, tv.geom);
            
            IF v_road_intersect_count = 0 THEN
                NEW.corregido := 'manual';
                NEW.requiere_edicion_manual := false;
                NEW.motivo_inconsistencia := NULL;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_detectar_correccion_manual_building ON jcm3.building;
CREATE TRIGGER trg_detectar_correccion_manual_building
BEFORE UPDATE OF geom ON jcm3.building
FOR EACH ROW
EXECUTE FUNCTION jcm3.fn_detectar_correccion_manual_building();

-- B. Trigger para jcm3.tramovial
CREATE OR REPLACE FUNCTION jcm3.fn_detectar_correccion_manual_tramovial()
RETURNS trigger AS $$
DECLARE
    v_building_intersect_count integer;
    v_crossing_count integer;
BEGIN
    IF OLD.corregido = 'no' THEN
        -- 1. Verificar si sigue solapándose con edificios
        IF OLD.tipo_error = 'TramoVia solape building' THEN
            SELECT COUNT(*) INTO v_building_intersect_count
            FROM jcm3.building b
            WHERE ST_Intersects(NEW.geom, b.geom);
            
            IF v_building_intersect_count = 0 THEN
                NEW.corregido := 'manual';
                NEW.requiere_edicion_manual := false;
                NEW.motivo_inconsistencia := NULL;
            END IF;
        END IF;

        -- 2. Verificar si sigue cruzando viales sin nodo
        IF OLD.tipo_error = 'TramoVia cruce sin nodo' THEN
            SELECT COUNT(*) INTO v_crossing_count
            FROM jcm3.tramovial tv
            WHERE tv.gid <> NEW.gid
              AND ST_Intersects(NEW.geom, tv.geom)
              AND ST_Relate(NEW.geom, tv.geom, '0********');
              
            IF v_crossing_count = 0 THEN
                NEW.corregido := 'manual';
                NEW.requiere_edicion_manual := false;
                NEW.motivo_inconsistencia := NULL;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_detectar_correccion_manual_tramovial ON jcm3.tramovial;
CREATE TRIGGER trg_detectar_correccion_manual_tramovial
BEFORE UPDATE OF geom ON jcm3.tramovial
FOR EACH ROW
EXECUTE FUNCTION jcm3.fn_detectar_correccion_manual_tramovial();
