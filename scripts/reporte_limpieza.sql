-- ============================================================================
-- SCRIPT DE REPORTE Y ANÁLISIS DE LIMPIEZA DE DATOS (jcm1 -> jcm2)
-- Lee de forma instantánea de la tabla de logs de trazabilidad jcm2.log_calidad_geometrias
-- ============================================================================

SELECT 
    tabla,
    total_origen_buffer AS total_jcm1,
    (CASE 
        WHEN tabla = 'building' THEN (SELECT COUNT(*) FROM jcm2.building)
        WHEN tabla = 'buildingpart' THEN (SELECT COUNT(*) FROM jcm2.buildingpart)
        WHEN tabla = 'cadastralparcel' THEN (SELECT COUNT(*) FROM jcm2.cadastralparcel)
        WHEN tabla = 'tramovial' THEN (SELECT COUNT(*) FROM jcm2.tramovial)
        WHEN tabla = 'portalpk' THEN (SELECT COUNT(*) FROM jcm2.portalpk)
        WHEN tabla = 'tramocurso' THEN (SELECT COUNT(*) FROM jcm2.tramocurso)
        WHEN tabla = 'siose_pol' THEN (SELECT COUNT(*) FROM jcm2.siose_pol)
        ELSE 0
     END) AS total_jcm2,
    originales_invalidas AS invalidos,
    (CASE 
        WHEN tabla = 'building' THEN (SELECT COUNT(*) FROM jcm2.building WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'buildingpart' THEN (SELECT COUNT(*) FROM jcm2.buildingpart WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'cadastralparcel' THEN (SELECT COUNT(*) FROM jcm2.cadastralparcel WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'tramovial' THEN (SELECT COUNT(*) FROM jcm2.tramovial WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'portalpk' THEN (SELECT COUNT(*) FROM jcm2.portalpk WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'tramocurso' THEN (SELECT COUNT(*) FROM jcm2.tramocurso WHERE ST_NumGeometries(geom) > 1)
        WHEN tabla = 'siose_pol' THEN (SELECT COUNT(*) FROM jcm2.siose_pol WHERE ST_NumGeometries(geom) > 1)
        ELSE 0
     END) AS multiparte,
    filtradas_escala AS micro,
    (corruptas_descartadas + filtradas_conversion_2d) AS incoherencias
FROM jcm2.log_calidad_geometrias
WHERE tabla <> 'municipio'
ORDER BY 
    CASE 
        WHEN tabla = 'building' THEN 1
        WHEN tabla = 'buildingpart' THEN 2
        WHEN tabla = 'cadastralparcel' THEN 3
        WHEN tabla = 'tramovial' THEN 4
        WHEN tabla = 'portalpk' THEN 5
        WHEN tabla = 'tramocurso' THEN 6
        WHEN tabla = 'siose_pol' THEN 7
        ELSE 8
    END;
