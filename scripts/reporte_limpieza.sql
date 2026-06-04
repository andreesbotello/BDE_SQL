-- ============================================================================
-- SCRIPT DE REPORTE Y ANÁLISIS DE LIMPIEZA DE DATOS (jcm1 -> jcm2)
-- Compara el volumen y calidad geométrica/semántica de los datos originales
-- dentro del área de estudio de 500m frente a los datos depurados en jcm2.
-- ============================================================================

-- 1. Métricas de Calidad para Edificios (building)
SELECT 
    'building' AS tabla,
    (SELECT COUNT(*) FROM jcm1.building b, jcm2.ttmm m WHERE ST_DWithin(b.geom, m.geom, 500)) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.building) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.building b, jcm2.ttmm m WHERE ST_DWithin(b.geom, m.geom, 500) AND NOT ST_IsValid(b.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.building b, jcm2.ttmm m WHERE ST_DWithin(b.geom, m.geom, 500) AND ST_NumGeometries(b.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.building b, jcm2.ttmm m WHERE ST_DWithin(b.geom, m.geom, 500) AND ST_Area(b.geom) < 0.5) AS micro_geometrias_jcm1,
    (SELECT COUNT(*) FROM jcm1.building b, jcm2.ttmm m WHERE ST_DWithin(b.geom, m.geom, 500) AND (numberofbuildingunits < 0 OR value < 0 OR currentuse NOT IN ('residential', 'agriculture', 'industrial', 'commerceAndServices', 'publicServices', 'office', 'educational', 'health', 'recreational', 'other', 'ancillary'))) AS incoherencias_jcm1

UNION ALL

-- 2. Métricas de Calidad para Partes de Edificios (buildingpart)
SELECT 
    'buildingpart' AS tabla,
    (SELECT COUNT(*) FROM jcm1.buildingpart bp, jcm2.ttmm m WHERE ST_DWithin(bp.geom, m.geom, 500)) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.buildingpart) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.buildingpart bp, jcm2.ttmm m WHERE ST_DWithin(bp.geom, m.geom, 500) AND NOT ST_IsValid(bp.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.buildingpart bp, jcm2.ttmm m WHERE ST_DWithin(bp.geom, m.geom, 500) AND ST_NumGeometries(bp.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.buildingpart bp, jcm2.ttmm m WHERE ST_DWithin(bp.geom, m.geom, 500) AND ST_Area(bp.geom) < 0.5) AS micro_geometrias_jcm1,
    (SELECT COUNT(*) FROM jcm1.buildingpart bp, jcm2.ttmm m WHERE ST_DWithin(bp.geom, m.geom, 500) AND (numberoffloorsaboveground < 0 OR numberoffloorsbelowground < 0)) AS incoherencias_jcm1

UNION ALL

-- 3. Métricas de Calidad para Parcelas Catastrales (cadastralparcel)
SELECT 
    'cadastralparcel' AS tabla,
    (SELECT COUNT(*) FROM jcm1.cadastralparcel cp, jcm2.ttmm m WHERE ST_DWithin(cp.geom, m.geom, 500)) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.cadastralparcel) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.cadastralparcel cp, jcm2.ttmm m WHERE ST_DWithin(cp.geom, m.geom, 500) AND NOT ST_IsValid(cp.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.cadastralparcel cp, jcm2.ttmm m WHERE ST_DWithin(cp.geom, m.geom, 500) AND ST_NumGeometries(cp.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.cadastralparcel cp, jcm2.ttmm m WHERE ST_DWithin(cp.geom, m.geom, 500) AND ST_Area(cp.geom) < 0.5) AS micro_geometrias_jcm1,
    0 AS incoherencias_jcm1

UNION ALL

-- 4. Métricas de Calidad para Tramos Viales (tramovial)
SELECT 
    'tramovial' AS tabla,
    (SELECT COUNT(*) FROM jcm1.tramovial tv, jcm2.ttmm m WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.tramovial) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.tramovial tv, jcm2.ttmm m WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND NOT ST_IsValid(tv.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.tramovial tv, jcm2.ttmm m WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND ST_NumGeometries(tv.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.tramovial tv, jcm2.ttmm m WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND ST_Length(ST_Transform(tv.geom, 25830)) < 0.5) AS micro_geometrias_jcm1,
    (SELECT COUNT(*) FROM jcm1.tramovial tv, jcm2.ttmm m WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND NOT ST_IsSimple(tv.geom)) AS incoherencias_jcm1

UNION ALL

-- 5. Métricas de Calidad para Portales (portalpk)
SELECT 
    'portalpk' AS tabla,
    (SELECT COUNT(*) FROM jcm1.portalpk pk, jcm2.ttmm m WHERE ST_Intersects(pk.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.portalpk) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.portalpk pk, jcm2.ttmm m WHERE ST_Intersects(pk.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND NOT ST_IsValid(pk.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.portalpk pk, jcm2.ttmm m WHERE ST_Intersects(pk.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND ST_NumGeometries(pk.geom) > 1) AS multiparte_jcm1,
    0 AS micro_geometrias_jcm1,
    0 AS incoherencias_jcm1

UNION ALL

-- 6. Métricas de Calidad para Hidrografía (tramocurso)
SELECT 
    'tramocurso' AS tabla,
    (SELECT COUNT(*) FROM jcm1.tramocurso tc, jcm2.ttmm m WHERE ST_Intersects(tc.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.tramocurso) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.tramocurso tc, jcm2.ttmm m WHERE ST_Intersects(tc.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND NOT ST_IsValid(tc.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.tramocurso tc, jcm2.ttmm m WHERE ST_Intersects(tc.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND ST_NumGeometries(tc.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.tramocurso tc, jcm2.ttmm m WHERE ST_Intersects(tc.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258)) AND ST_Length(ST_Transform(tc.geom, 25830)) < 0.5) AS micro_geometrias_jcm1,
    0 AS incoherencias_jcm1

UNION ALL

-- 7. Métricas de Calidad para Polígonos SIOSE (siose_pol)
SELECT 
    'siose_pol' AS tabla,
    (SELECT COUNT(*) FROM jcm1.siose_pol s, jcm2.ttmm m WHERE ST_DWithin(s.geom, m.geom, 500)) AS total_jcm1_buffer,
    (SELECT COUNT(*) FROM jcm2.siose_pol) AS total_jcm2,
    (SELECT COUNT(*) FROM jcm1.siose_pol s, jcm2.ttmm m WHERE ST_DWithin(s.geom, m.geom, 500) AND NOT ST_IsValid(s.geom)) AS invalidos_jcm1,
    (SELECT COUNT(*) FROM jcm1.siose_pol s, jcm2.ttmm m WHERE ST_DWithin(s.geom, m.geom, 500) AND ST_NumGeometries(s.geom) > 1) AS multiparte_jcm1,
    (SELECT COUNT(*) FROM jcm1.siose_pol s, jcm2.ttmm m WHERE ST_DWithin(s.geom, m.geom, 500) AND ST_Area(s.geom) < 0.5) AS micro_geometrias_jcm1,
    0 AS incoherencias_jcm1;
