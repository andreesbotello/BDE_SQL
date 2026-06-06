-- ============================================================================
-- CONSULTAS DE CONTROL DE CALIDAD Y ANÁLISIS GEOMÉTRICO DETALLADO
-- ============================================================================

-- CONSULTA 1: Elementos no simples (ST_IsSimple = false) en jcm1.tramovial y jcm1.tramocurso
-- dentro del buffer de 500m del municipio.
-- ----------------------------------------------------------------------------
-- [CONSULTA_1A] Tramos viales no simples
SELECT 
    'tramovial' AS capa,
    tv.id_tramo AS elemento_id,
    ST_AsText(ST_Transform(tv.geom, 25830)) AS geom_wkt
FROM jcm1.tramovial tv
CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
WHERE tv.geom IS NOT NULL
  AND ST_DWithin(ST_Transform(tv.geom, 25830), m.geom, 500)
  AND NOT ST_IsSimple(ST_Transform(tv.geom, 25830));

-- [CONSULTA_1B] Cursos de agua no simples
SELECT 
    'tramocurso' AS capa,
    tc.id_curso AS elemento_id,
    ST_AsText(ST_Transform(tc.geom, 25830)) AS geom_wkt
FROM jcm1.tramocurso tc
CROSS JOIN (SELECT ST_Union(geom) AS geom FROM jcm2.municipio) m
WHERE tc.geom IS NOT NULL
  AND ST_DWithin(ST_Transform(tc.geom, 25830), m.geom, 500)
  AND NOT ST_IsSimple(ST_Transform(tc.geom, 25830));


-- CONSULTA 2: Elementos inválidos en origen en jcm2.log_detalle_calidad y sus razones de invalidez
-- ----------------------------------------------------------------------------
-- [CONSULTA_2] Elementos inválidos y razones
SELECT 
    tabla,
    gml_id AS elemento_id,
    ST_IsValidReason(geom_original) AS razon_invalidez
FROM jcm2.log_detalle_calidad
WHERE NOT es_valida_original;


-- CONSULTA 3: Elementos descartados por escala (microgeometrías / slivers < 0.5m2)
-- ----------------------------------------------------------------------------
-- [CONSULTA_3] Slivers descartados
SELECT 
    tabla,
    gml_id AS elemento_id,
    ST_Area(geom_original) AS area_m2
FROM jcm2.log_detalle_calidad
WHERE motivo_descarte = 'escala_micro';


-- CONSULTA 4: Distribución del número de sub-geometrías en elementos multiparte
-- ----------------------------------------------------------------------------
-- [CONSULTA_4] Distribución de partes por tabla
SELECT 'building' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.building GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'buildingpart' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.buildingpart GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'cadastralparcel' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.cadastralparcel GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'tramovial' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.tramovial GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'portalpk' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.portalpk GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'tramocurso' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.tramocurso GROUP BY ST_NumGeometries(geom)
UNION ALL
SELECT 'siose_pol' AS tabla, COALESCE(ST_NumGeometries(geom), 0) AS num_partes, COUNT(*) AS total
FROM jcm2.siose_pol GROUP BY ST_NumGeometries(geom)
ORDER BY tabla, num_partes;


-- CONSULTA 5: Propuesta de Nuevos Controles de Calidad (Auditorías de Integridad)
-- ----------------------------------------------------------------------------
-- [PROPUESTA_5A] Chequeo de consistencia entre la superficie catastral declarada y la calculada
-- Se buscan discrepancias mayores al 10% en parcelas de tamaño considerable (> 10 m2)
SELECT 
    gml_id AS elemento_id,
    areavalue AS area_declarada_catastro,
    ROUND(ST_Area(geom)::numeric, 2) AS area_calculada_gis,
    ROUND(ABS(areavalue - ST_Area(geom))::numeric, 2) AS diferencia_absoluta,
    ROUND((ABS(areavalue - ST_Area(geom)) / areavalue * 100)::numeric, 2) AS porcentaje_desviacion
FROM jcm2.cadastralparcel
WHERE areavalue > 10 
  AND (ABS(areavalue - ST_Area(geom)) / areavalue) > 0.1
ORDER BY porcentaje_desviacion DESC;

-- [PROPUESTA_5B] Chequeo de integridad topológica: Partes de edificios (buildingpart) huérfanas
-- Se buscan partes de edificios que no intersecten espacialmente con ningún edificio (building)
SELECT 
    bp.gml_id AS bp_id
FROM jcm2.buildingpart bp
WHERE NOT EXISTS (
    SELECT 1 
    FROM jcm2.building b 
    WHERE ST_Intersects(bp.geom, b.geom)
);
