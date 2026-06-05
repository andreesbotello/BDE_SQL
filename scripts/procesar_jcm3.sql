-- ============================================================================
-- SCRIPT DE PROCESAMIENTO Y ANÁLISIS DEL ESQUEMA jcm3
-- Proyecto Final: Bases de Datos Espaciales
-- ============================================================================

-- 1. LIMPIEZA DE TABLAS Y VISTAS EXISTENTES EN jcm3
-- ============================================================================
DROP VIEW IF EXISTS jcm3.vista_q8_5_2 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_5_1 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_4 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_3 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_2 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_1_3 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_1_2 CASCADE;
DROP VIEW IF EXISTS jcm3.vista_q8_1_1 CASCADE;
DROP VIEW IF EXISTS jcm3.parcelas_candidatas_centro CASCADE;
DROP VIEW IF EXISTS jcm3.building_solapes_intersecciones CASCADE;
DROP VIEW IF EXISTS jcm3.building_solapes_agrupada CASCADE;
DROP VIEW IF EXISTS jcm3.building_solapes_agrupada_1m2 CASCADE;
DROP TABLE IF EXISTS jcm3.building_solapes_alfanumerica CASCADE;
DROP VIEW IF EXISTS jcm3.solapes_edificios CASCADE;
DROP VIEW IF EXISTS jcm3.cruces_viales_puntos CASCADE;
DROP VIEW IF EXISTS jcm3.cruces_viales_puntos_baseline CASCADE;
DROP VIEW IF EXISTS jcm3.vial_edificio_intersecciones CASCADE;
DROP VIEW IF EXISTS jcm3.vial_edificio_corregidos CASCADE;
DROP VIEW IF EXISTS jcm3.vial_edificio_no_resueltos CASCADE;
DROP TABLE IF EXISTS jcm3.vial_edificio_reporte CASCADE;
DROP TABLE IF EXISTS jcm3.vial_stubs_reporte CASCADE;
DROP TABLE IF EXISTS jcm3.building CASCADE;
DROP TABLE IF EXISTS jcm3.tramovial CASCADE;

CREATE SCHEMA IF NOT EXISTS jcm3;

-- Eliminar restos de ejecuciones de prueba previas en jcm2
DELETE FROM jcm2.building WHERE gml_id = 'TEST_GML_ID_SOLAPADO';

-- ============================================================================
-- 2. CREACIÓN DE TABLAS DE DATOS CORREGIDOS (jcm3) Y LÓGICA DE CORRECCIÓN
-- ============================================================================

-- A. Capa de Edificios Corregidos (building)
CREATE TABLE jcm3.building AS SELECT * FROM jcm2.building;
ALTER TABLE jcm3.building ADD PRIMARY KEY (gid);
CREATE INDEX ON jcm3.building USING gist(geom);

-- Corrección automática de solapes menores a 0.5 m2 mediante snapping/diferencia
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_solapes_edificios()
RETURNS void AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT b1.gid AS gid1, b2.gid AS gid2
        FROM jcm3.building b1
        JOIN jcm3.building b2 ON ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid
        WHERE ST_Area(ST_Intersection(b1.geom, b2.geom)) < 0.5
    LOOP
        -- Asegurar que siguen solapándose en esta iteración
        IF EXISTS (
            SELECT 1 FROM jcm3.building b1, jcm3.building b2
            WHERE b1.gid = r.gid1 AND b2.gid = r.gid2 AND ST_Overlaps(b1.geom, b2.geom)
        ) THEN
            UPDATE jcm3.building
            SET geom = ST_Multi(STX_Extract(ST_Difference(geom, (SELECT geom FROM jcm3.building WHERE gid = r.gid1)), 3))
            WHERE gid = r.gid2;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT jcm3.fn_corregir_solapes_edificios();

-- B. Capa de Vías Corregidas (tramovial) y reportes de corrección
CREATE TABLE jcm3.tramovial AS SELECT * FROM jcm2.tramovial;
ALTER TABLE jcm3.tramovial ADD PRIMARY KEY (gid);
CREATE INDEX ON jcm3.tramovial USING gist(geom);

CREATE TABLE jcm3.vial_edificio_reporte (
    tv_gid integer PRIMARY KEY,
    b_gid integer,
    estado varchar
);

CREATE TABLE jcm3.vial_stubs_reporte (
    tv_gid integer PRIMARY KEY,
    estado varchar
);

-- Corrección automatizada de intersecciones vial-edificio (Reglas 1.1 y 1.2)
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
            
            UPDATE jcm3.tramovial SET geom = new_geom WHERE gid = r.tv_gid;
            
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
                        
                        detour_chosen := NULL;
                        IF NOT intersect_others_1 AND NOT intersect_others_2 THEN
                            IF detour_len1 < detour_len2 THEN
                                detour_chosen := detour_1;
                            ELSE
                                detour_chosen := detour_2;
                            END IF;
                        ELSIF NOT intersect_others_1 THEN
                            detour_chosen := detour_1;
                        ELSIF NOT intersect_others_2 THEN
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
                            
                            UPDATE jcm3.tramovial SET geom = ST_Multi(new_geom) WHERE gid = r.tv_gid;
                            
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

SELECT jcm3.fn_corregir_vial_edificio();

-- Corrección automatizada de stubs / solapes por escala en cruces (Reglas 3.1 y 3.2)
CREATE OR REPLACE FUNCTION jcm3.fn_corregir_stubs()
RETURNS void AS $$
DECLARE
    r record;
    line1 geometry;
    pt geometry;
    frac_p double precision;
    sub_a geometry;
    sub_b geometry;
    has_continuity_a boolean;
    has_continuity_b boolean;
BEGIN
    FOR r IN
        SELECT 
            tv1.gid AS tv1_gid,
            tv2.gid AS tv2_gid,
            ST_GeometryN(tv1.geom, 1) as line1,
            ST_GeometryN(tv2.geom, 1) as line2,
            (ST_Dump(ST_Intersection(tv1.geom, tv2.geom))).geom AS pt
        FROM jcm3.tramovial tv1
        JOIN jcm3.tramovial tv2 ON ST_Intersects(tv1.geom, tv2.geom) AND tv1.gid < tv2.gid
        WHERE ST_Relate(tv1.geom, tv2.geom, '0********')
    LOOP
        line1 := r.line1;
        pt := r.pt;
        
        frac_p := ST_LineLocatePoint(line1, pt);
        
        -- Solo si intersecta realmente en el interior del tramo
        IF frac_p > 0.0 AND frac_p < 1.0 THEN
            sub_a := ST_LineSubstring(line1, 0, frac_p);
            sub_b := ST_LineSubstring(line1, frac_p, 1);
            
            -- Evaluar segmento sub_a (extremo inicial)
            IF ST_Length(sub_a) < 1.0 AND ST_Length(sub_a) > 0.0 THEN
                SELECT EXISTS (
                    SELECT 1 FROM jcm3.tramovial tv
                    WHERE tv.gid <> r.tv1_gid
                      AND ST_DWithin(tv.geom, ST_StartPoint(sub_a), 0.001)
                ) INTO has_continuity_a;
                
                IF NOT has_continuity_a THEN
                    UPDATE jcm3.tramovial SET geom = ST_Multi(sub_b) WHERE gid = r.tv1_gid;
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Stub Eliminado')
                    ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                ELSE
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                    ON CONFLICT (tv_gid) DO NOTHING;
                END IF;
            ELSIF ST_Length(sub_a) >= 1.0 THEN
                SELECT EXISTS (
                    SELECT 1 FROM jcm3.tramovial tv
                    WHERE tv.gid <> r.tv1_gid
                      AND ST_DWithin(tv.geom, ST_StartPoint(sub_a), 0.001)
                ) INTO has_continuity_a;
                
                IF NOT has_continuity_a THEN
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                    ON CONFLICT (tv_gid) DO NOTHING;
                END IF;
            END IF;
            
            -- Evaluar segmento sub_b (extremo final)
            IF ST_Length(sub_b) < 1.0 AND ST_Length(sub_b) > 0.0 THEN
                SELECT EXISTS (
                    SELECT 1 FROM jcm3.tramovial tv
                    WHERE tv.gid <> r.tv1_gid
                      AND ST_DWithin(tv.geom, ST_EndPoint(sub_b), 0.001)
                ) INTO has_continuity_b;
                
                IF NOT has_continuity_b THEN
                    UPDATE jcm3.tramovial SET geom = ST_Multi(sub_a) WHERE gid = r.tv1_gid;
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Stub Eliminado')
                    ON CONFLICT (tv_gid) DO UPDATE SET estado = EXCLUDED.estado;
                ELSE
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                    ON CONFLICT (tv_gid) DO NOTHING;
                END IF;
            ELSIF ST_Length(sub_b) >= 1.0 THEN
                SELECT EXISTS (
                    SELECT 1 FROM jcm3.tramovial tv
                    WHERE tv.gid <> r.tv1_gid
                      AND ST_DWithin(tv.geom, ST_EndPoint(sub_b), 0.001)
                ) INTO has_continuity_b;
                
                IF NOT has_continuity_b THEN
                    INSERT INTO jcm3.vial_stubs_reporte (tv_gid, estado)
                    VALUES (r.tv1_gid, 'Calle Cerrada Válida')
                    ON CONFLICT (tv_gid) DO NOTHING;
                END IF;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT jcm3.fn_corregir_stubs();


-- ============================================================================
-- 3. REGLAS TOPOLÓGICAS AUDITADAS Y FILTRADAS (SECCIÓN 7)
-- ============================================================================

-- 7.2.1. Intersecciones Vial - Edificio (Auditoría maestra y clasificada)
CREATE OR REPLACE VIEW jcm3.vial_edificio_intersecciones AS
SELECT 
    row_number() OVER () AS gid,
    b.gid AS building_gid,
    tv.gid AS tramovial_gid,
    b.gml_id AS building_gml_id,
    tv.id_tramo AS tramovial_id,
    ST_Length(STX_Extract(ST_Intersection(b.geom, tv.geom), 2)) AS longitud,
    COALESCE(r.estado, 'Sin Error') AS estado,
    ST_Multi(STX_Extract(ST_Intersection(b.geom, tv.geom), 2))::geometry(MultiLineString, {{SRID_PROYECTO}}) AS geom
FROM jcm2.building b
JOIN jcm2.tramovial tv ON ST_Intersects(b.geom, tv.geom)
LEFT JOIN jcm3.vial_edificio_reporte r ON r.tv_gid = tv.gid AND r.b_gid = b.gid
WHERE STX_Extract(ST_Intersection(b.geom, tv.geom), 2) IS NOT NULL;

CREATE OR REPLACE VIEW jcm3.vial_edificio_corregidos AS
SELECT * FROM jcm3.vial_edificio_intersecciones
WHERE estado LIKE 'Corregido%';

CREATE OR REPLACE VIEW jcm3.vial_edificio_no_resueltos AS
SELECT * FROM jcm3.vial_edificio_intersecciones
WHERE estado LIKE 'No Resuelto%';

-- 7.2.2. Cruces viales en interior ( Baseline vs Corregidos con Dump a Point )
CREATE OR REPLACE VIEW jcm3.cruces_viales_puntos_baseline AS
SELECT 
    row_number() OVER () AS gid,
    tv1.gid AS tramovial_gid1,
    tv2.gid AS tramovial_gid2,
    tv1.id_tramo AS tramovial_id1,
    tv2.id_tramo AS tramovial_id2,
    (ST_Dump(ST_Multi(STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1)))).geom::geometry(Point, {{SRID_PROYECTO}}) AS geom
FROM jcm2.tramovial tv1
JOIN jcm2.tramovial tv2 ON ST_Intersects(tv1.geom, tv2.geom) AND tv1.gid < tv2.gid
WHERE ST_Relate(tv1.geom, tv2.geom, '0********')
  AND STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1) IS NOT NULL;

CREATE OR REPLACE VIEW jcm3.cruces_viales_puntos AS
SELECT 
    row_number() OVER () AS gid,
    tv1.gid AS tramovial_gid1,
    tv2.gid AS tramovial_gid2,
    tv1.id_tramo AS tramovial_id1,
    tv2.id_tramo AS tramovial_id2,
    (ST_Dump(ST_Multi(STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1)))).geom::geometry(Point, {{SRID_PROYECTO}}) AS geom
FROM jcm3.tramovial tv1
JOIN jcm3.tramovial tv2 ON ST_Intersects(tv1.geom, tv2.geom) AND tv1.gid < tv2.gid
WHERE ST_Relate(tv1.geom, tv2.geom, '0********')
  AND STX_Extract(ST_Intersection(tv1.geom, tv2.geom), 1) IS NOT NULL;

-- 7.2.3. Otras Reglas - Solapes de Edificios (Sobre capa corregida jcm3.building)
CREATE TABLE jcm3.building_solapes_alfanumerica AS
SELECT 
    b1.gid AS gid1, 
    b2.gid AS gid2, 
    b1.gml_id AS gml_id1, 
    b2.gml_id AS gml_id2
FROM jcm3.building b1, jcm3.building b2
WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid;

CREATE OR REPLACE VIEW jcm3.building_solapes_agrupada AS
SELECT 
    b1.gid AS gid, 
    count(b2.gid) AS nsolapes,
    array_agg(b2.gid)::varchar AS listasolapes, 
    b1.geom AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid <> b2.gid
GROUP BY b1.gid;

CREATE OR REPLACE VIEW jcm3.building_solapes_agrupada_1m2 AS
SELECT 
    b1.gid AS gid, 
    count(b2.gid) AS nsolapes,
    array_agg(b2.gid)::varchar AS listasolapes, 
    b1.geom AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid <> b2.gid
  AND ST_Area(ST_Intersection(b1.geom, b2.geom)) > 1.0
GROUP BY b1.gid;

CREATE OR REPLACE VIEW jcm3.building_solapes_intersecciones AS
SELECT 
    row_number() OVER () AS gid,
    b1.gid AS building_gid1, 
    b2.gid AS building_gid2,
    ST_Area(ST_Intersection(b1.geom, b2.geom)) AS area_solape,
    ST_Multi(STX_Extract(ST_Intersection(b1.geom, b2.geom), 3))::geometry(MultiPolygon, {{SRID_PROYECTO}}) AS geom
FROM jcm3.building b1, jcm3.building b2
WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid;


-- ============================================================================
-- 4. CONSULTAS ANALÍTICAS ESPACIALES CORREGIDAS (SECCIÓN 8)
-- ============================================================================

-- 8.1.1. ¿Cuántas parcelas tienen algún edificio en su interior?
CREATE OR REPLACE VIEW jcm3.vista_q8_1_1 AS
SELECT COUNT(*) AS total_parcelas_con_edificios
FROM jcm2.cadastralparcel cp
WHERE EXISTS (
    SELECT 1 
    FROM jcm3.building b 
    WHERE ST_Intersects(cp.geom, b.geom)
);

-- 8.1.2. ¿Cuántas parcelas no tienen ningún edificio en su interior (sin GROUP BY)?
CREATE OR REPLACE VIEW jcm3.vista_q8_1_2 AS
SELECT COUNT(*) AS total_parcelas_vacias
FROM jcm2.cadastralparcel cp
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm3.building b 
    WHERE ST_Intersects(cp.geom, b.geom)
);

-- 8.1.3. ¿Cuál es la referencia catastral (gml_id) de la parcela que tiene más edificios en su interior?
CREATE OR REPLACE VIEW jcm3.vista_q8_1_3 AS
SELECT cp.gml_id, COUNT(b.gid) AS num_edificios
FROM jcm2.cadastralparcel cp
JOIN jcm3.building b ON ST_Intersects(cp.geom, b.geom)
GROUP BY cp.gml_id, cp.gid
ORDER BY num_edificios DESC, cp.gml_id ASC
LIMIT 1;

-- 8.2. ¿Cuántos edificios aislados (sin otros edificios en 100m) hay?
CREATE OR REPLACE VIEW jcm3.vista_q8_2 AS
SELECT COUNT(*) AS total_edificios_aislados
FROM jcm3.building b1
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm3.building b2 
    WHERE b1.gid <> b2.gid 
      AND ST_DWithin(b1.geom, b2.geom, 100)
);

CREATE OR REPLACE VIEW jcm3.vista_q8_3 AS
SELECT 
    s.codiige,
    c.descripcion AS suelo_descripcion,
    ROUND(SUM(ST_Area(ST_Intersection(b.geom, s.geom)))::numeric, 2) AS area_edificada_m2
FROM jcm3.building b
JOIN jcm2.siose_pol s ON ST_Intersects(b.geom, s.geom) AND NOT ST_Touches(b.geom, s.geom)
LEFT JOIN jcm2.siose_codiige c ON s.codiige = c.codiige
GROUP BY s.codiige, c.descripcion
ORDER BY area_edificada_m2 DESC
LIMIT 5;

-- 8.4. Edificios y volumen de sótanos (Floors below ground x Area x 2.5) usando left(bp.gml_id, 25)
CREATE OR REPLACE VIEW jcm3.vista_q8_4 AS
SELECT 
    b.gml_id AS building_gml_id,
    ROUND(SUM(ST_Area(bp.geom) * bp.numberoffloorsbelowground * 2.5)::numeric, 2) AS volumen_sotanos_m3
FROM jcm3.building b
JOIN jcm2.buildingpart bp ON LEFT(bp.gml_id, 25) = b.gml_id
WHERE bp.numberoffloorsbelowground > 0
GROUP BY b.gml_id, b.gid
ORDER BY volumen_sotanos_m3 DESC
LIMIT 5;

-- 8.5. Consultas propuestas por el estudiante:
-- Consulta 1: Número de edificios situados en zona de potencial inundación (a menos de 50 metros de un río/arroyo)
CREATE OR REPLACE VIEW jcm3.vista_q8_5_1 AS
SELECT COUNT(DISTINCT b.gid) AS total_edificios_riesgo_inundacion
FROM jcm3.building b
JOIN jcm2.tramocurso tc ON ST_DWithin(b.geom, tc.geom, 50);

-- Consulta 2: Densidad edificada urbana: top 5 polígonos SIOSE urbanos de Estepona con mayor porcentaje edificado
CREATE OR REPLACE VIEW jcm3.vista_q8_5_2 AS
SELECT 
    s.gid AS siose_gid,
    s.codiige,
    c.descripcion AS suelo_descripcion,
    ROUND(ST_Area(s.geom)::numeric, 2) AS area_suelo_m2,
    ROUND(SUM(ST_Area(ST_Intersection(b.geom, s.geom)))::numeric, 2) AS area_edificada_m2,
    ROUND((SUM(ST_Area(ST_Intersection(b.geom, s.geom))) / ST_Area(s.geom) * 100)::numeric, 2) AS porcentaje_edificado
FROM jcm2.siose_pol s
JOIN jcm2.siose_codiige c ON s.codiige = c.codiige
JOIN jcm3.building b ON ST_Intersects(b.geom, s.geom)
WHERE c.descripcion IN ('Casco', 'Ensanche', 'Discontinuo', 'Industrial', 'Servicio dotacional')
GROUP BY s.gid, s.codiige, c.descripcion
HAVING ST_Area(s.geom) > 0
ORDER BY porcentaje_edificado DESC
LIMIT 5;


-- ============================================================================
-- 5. EJERCICIO DE ANÁLISIS ESPACIAL MULTICRITERIO CORREGIDO (SECCIÓN 9)
-- ============================================================================
CREATE OR REPLACE VIEW jcm3.parcelas_candidatas_centro AS
SELECT 
    cp.gid,
    cp.gml_id AS parcela_gml_id,
    cp.localid AS parcela_localid,
    ROUND(cp.areavalue::numeric, 2) AS area_parcela_m2,
    cp.geom
FROM jcm2.cadastralparcel cp
WHERE 
    cp.areavalue > 1500
    AND NOT EXISTS (
        SELECT 1 
        FROM jcm3.building b 
        WHERE ST_Intersects(cp.geom, b.geom)
    )
    AND EXISTS (
        SELECT 1 
        FROM jcm3.tramovial tv 
        WHERE ST_DWithin(cp.geom, tv.geom, 10) 
          AND tv.firmed = 'Pavimentado'
    )
    AND NOT EXISTS (
        SELECT 1 
        FROM jcm2.tramocurso tc 
        WHERE ST_DWithin(cp.geom, tc.geom, 100)
    )
    AND EXISTS (
        SELECT 1 
        FROM jcm2.siose_pol s
        WHERE ST_Intersects(cp.geom, s.geom)
          AND s.codiige BETWEEN 111 AND 140
    )
    AND (
        SELECT COUNT(*) 
        FROM jcm2.portalpk pk 
        WHERE ST_DWithin(cp.geom, pk.geom, 300)
    ) >= 10;


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
