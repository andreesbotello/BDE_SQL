-- ============================================================================
-- SCRIPT DE PREPARACIÓN PARA LA IMPORTACIÓN EN EL ESQUEMA jcm1
-- ============================================================================

-- Crear el esquema si no existe
CREATE SCHEMA IF NOT EXISTS jcm1;

-- Limpieza preventiva de tablas antes de la importación
DROP TABLE IF EXISTS jcm1.building CASCADE;
DROP TABLE IF EXISTS jcm1.buildingpart CASCADE;
DROP TABLE IF EXISTS jcm1.cadastralparcel CASCADE;
DROP TABLE IF EXISTS jcm1.tramovial CASCADE;
DROP TABLE IF EXISTS jcm1.portalpk CASCADE;
DROP TABLE IF EXISTS jcm1.tramocurso CASCADE;
DROP TABLE IF EXISTS jcm1.siose_pol CASCADE;
DROP TABLE IF EXISTS jcm1.siose_codiige CASCADE;
DROP TABLE IF EXISTS jcm1.siose_hilucs CASCADE;
DROP TABLE IF EXISTS jcm1.ttmm CASCADE;
