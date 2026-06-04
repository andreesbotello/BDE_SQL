-- ============================================================================
-- SECCIÓN: Configurar PostGIS y Esquemas (Ejecutar en la base de datos del proyecto)
-- ============================================================================

-- Habilitar la extensión espacial PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Crear los esquemas del proyecto
CREATE SCHEMA IF NOT EXISTS jcm1; -- Esquema de Importación (original)
CREATE SCHEMA IF NOT EXISTS jcm2; -- Esquema de Modelo de Datos (reproyectado y recortado)
CREATE SCHEMA IF NOT EXISTS jcm3; -- Esquema de Análisis Espacial

-- Función de extracción segura de geometrías (devolviendo NULL si no existe la dimensión en lugar de EMPTY)
CREATE OR REPLACE FUNCTION public.stx_extract(geom geometry, dimension integer)
RETURNS geometry AS $$
DECLARE
    res geometry;
BEGIN
    res := ST_CollectionExtract(geom, dimension);
    IF ST_IsEmpty(res) THEN
        RETURN NULL;
    ELSE
        RETURN res;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

