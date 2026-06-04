-- ============================================================================
-- REPORTE DE DIAGNÓSTICO Y CORRECCIONES TOPOLÓGICAS (jcm3)
-- ============================================================================

SELECT '1. SOLAPES DE EDIFICIOS (BUILDING)' AS seccion, '' AS detalle, 0::numeric AS cantidad
UNION ALL
SELECT '  - Solapes originales en jcm2', '', COUNT(*)
FROM (
    SELECT 1 FROM jcm2.building b1, jcm2.building b2
    WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid
) AS q
UNION ALL
SELECT '  - Solapes resueltos automáticamente (< 0.5 m2)', '', COUNT(*)
FROM (
    SELECT 1 FROM jcm2.building b1, jcm2.building b2
    WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid
      AND ST_Area(ST_Intersection(b1.geom, b2.geom)) < 0.5
) AS q
UNION ALL
SELECT '  - Solapes restantes en jcm3 (debería ser 0)', '', COUNT(*)
FROM (
    SELECT 1 FROM jcm3.building b1, jcm3.building b2
    WHERE ST_Overlaps(b1.geom, b2.geom) AND b1.gid < b2.gid
) AS q

UNION ALL

SELECT '2. INTERSECCIONES VIAL - EDIFICIO', '', 0
UNION ALL
SELECT '  - Vías originales que intersecan con edificios', '', COUNT(DISTINCT tv.gid)
FROM jcm2.tramovial tv
JOIN jcm2.building b ON ST_Intersects(tv.geom, b.geom)
UNION ALL
SELECT '  - Casos resueltos por Regla 1.1 (Finaliza dentro)', '', COUNT(*)
FROM jcm3.vial_edificio_reporte
WHERE estado = 'Corregido 1.1 (Finaliza dentro)'
UNION ALL
SELECT '  - Casos resueltos por Regla 1.2 (Bordeado)', '', COUNT(*)
FROM jcm3.vial_edificio_reporte
WHERE estado = 'Corregido 1.2 (Bordeado)'
UNION ALL
SELECT '  - Casos sin desvío libre (No Resuelto)', '', COUNT(*)
FROM jcm3.vial_edificio_reporte
WHERE estado = 'No Resuelto 1.2 (Sin desvío libre)'
UNION ALL
SELECT '  - Cruces complejos / largos (No Resuelto)', '', COUNT(*)
FROM jcm3.vial_edificio_reporte
WHERE estado LIKE 'No Resuelto%' AND estado <> 'No Resuelto 1.2 (Sin desvío libre)'
UNION ALL
SELECT '  - Vías corregidas que aún intersecan (restantes)', '', COUNT(DISTINCT tv.gid)
FROM jcm3.tramovial tv
JOIN jcm3.building b ON ST_Intersects(tv.geom, b.geom)

UNION ALL

SELECT '3. CRUCES VIALES Y STUBS (CONECTIVIDAD)', '', 0
UNION ALL
SELECT '  - Cruces viales totales en interior (originales)', '', COUNT(*)
FROM jcm3.cruces_viales_puntos_baseline
UNION ALL
SELECT '  - Stubs de escala eliminados automáticamente (< 1m)', '', COUNT(*)
FROM jcm3.vial_stubs_reporte
WHERE estado = 'Stub Eliminado'
UNION ALL
SELECT '  - Calles cerradas / callejones sin salida válidos (>= 1m)', '', COUNT(*)
FROM jcm3.vial_stubs_reporte
WHERE estado = 'Calle Cerrada Válida'
UNION ALL
SELECT '  - Cruces viales restantes en jcm3', '', COUNT(*)
FROM jcm3.cruces_viales_puntos;
