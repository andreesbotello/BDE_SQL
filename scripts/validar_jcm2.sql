-- ============================================================================
-- SCRIPT DE VALIDACIÓN E INTEGRIDAD GEOMÉTRICA PARA EL ESQUEMA jcm2
-- ============================================================================

SELECT 'ttmm' AS tabla, COUNT(*) AS total, COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) AS invalidos FROM jcm2.ttmm
UNION ALL
SELECT 'building', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.building
UNION ALL
-- Partes de edificios
SELECT 'buildingpart', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.buildingpart
UNION ALL
-- Parcelas catastrales
SELECT 'cadastralparcel', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.cadastralparcel
UNION ALL
-- Tramos viales
SELECT 'tramovial', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.tramovial
UNION ALL
-- Portales y PKs
SELECT 'portalpk', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.portalpk
UNION ALL
-- Red de hidrografía
SELECT 'tramocurso', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.tramocurso
UNION ALL
-- SIOSE Polígonos
SELECT 'siose_pol', COUNT(*), COUNT(CASE WHEN NOT ST_IsValid(geom) THEN 1 END) FROM jcm2.siose_pol
UNION ALL
-- SIOSE Alfanumérica: Clasificación de cobertura
SELECT 'siose_codiige', COUNT(*), NULL FROM jcm2.siose_codiige
UNION ALL
-- SIOSE Alfanumérica: Clasificación de usos
SELECT 'siose_hilucs', COUNT(*), NULL FROM jcm2.siose_hilucs;
