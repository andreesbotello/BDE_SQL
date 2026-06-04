-- ============================================================================
-- SCRIPT DE PROCESAMIENTO Y CREACIÓN DEL ESQUEMA jcm2
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
DROP TABLE IF EXISTS jcm2.ttmm CASCADE;

-- 2. CREACIÓN DE TABLAS CON EL SRS DEL PROYECTO (EPSG:25830) Y 2D
-- ============================================================================

-- 2.1. Término Municipal (ttmm)
CREATE TABLE jcm2.ttmm (
    gid serial PRIMARY KEY,
    inspireid varchar,
    natcode varchar,
    nameunit varchar,
    geom geometry(MultiPolygon, 25830)
);

-- 2.2. Edificios (building)
CREATE TABLE jcm2.building (
    gid serial PRIMARY KEY,
    gml_id varchar,
    current_use_in varchar,
    currentuse varchar,
    numberofbuildingunits integer,
    value integer,
    geom geometry(MultiPolygon, 25830)
);

-- 2.3. Partes de Edificios (buildingpart)
CREATE TABLE jcm2.buildingpart (
    gid serial PRIMARY KEY,
    gml_id varchar,
    numberoffloorsaboveground integer,
    numberoffloorsbelowground integer,
    geom geometry(MultiPolygon, 25830)
);

-- 2.4. Parcelas Catastrales (cadastralparcel)
CREATE TABLE jcm2.cadastralparcel (
    gid serial PRIMARY KEY,
    gml_id varchar,
    areavalue numeric,
    localid varchar,
    geom geometry(MultiPolygon, 25830)
);

-- 2.5. Tramos Viales (tramovial)
CREATE TABLE jcm2.tramovial (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    clased varchar,
    nombre varchar,
    firmed varchar,
    geom geometry(MultiLineString, 25830)
);

-- 2.6. Portales y Puntos Kilométricos (portalpk)
CREATE TABLE jcm2.portalpk (
    gid serial PRIMARY KEY,
    id_tramo varchar,
    id_vial varchar,
    id_porpk varchar,
    numero varchar,
    geom geometry(MultiPoint, 25830)
);

-- 2.7. Red de Hidrografía (tramocurso)
CREATE TABLE jcm2.tramocurso (
    gid serial PRIMARY KEY,
    id_curso varchar,
    nombre varchar,
    tipo_curso varchar,
    geom geometry(MultiLineString, 25830)
);

-- 2.8. SIOSE Polígonos (siose_pol)
CREATE TABLE jcm2.siose_pol (
    gid serial PRIMARY KEY,
    id_polygon varchar,
    codiige integer,
    hilucs integer,
    geom geometry(MultiPolygon, 25830)
);
-- 3. INSERCIÓN DE DATOS REPROYECTADOS, EN 2D Y RECORTADOS A LA ZONA DE ESTUDIO (500M)
-- OPTIMIZACIÓN: Limpieza y validación preventiva durante la inserción.
-- ============================================================================

-- 3.1. Insertar el Municipio de Estudio (Estepona)
-- Nota: La plantilla de Python reemplazará {{CODIGO_MUNICIPIO}} por el valor real.
INSERT INTO jcm2.ttmm (inspireid, natcode, nameunit, geom)
SELECT inspireid, natcode, nameunit, ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(geom, 25830))))
FROM jcm1.ttmm
WHERE (natcode = '3417' || SUBSTRING('{{CODIGO_MUNICIPIO}}', 1, 2) || '{{CODIGO_MUNICIPIO}}'
   OR natcode LIKE '%' || '{{CODIGO_MUNICIPIO}}')
  AND geom IS NOT NULL;

-- Crear índice espacial temporal en jcm2.ttmm para acelerar la cláusula ST_DWithin posterior
CREATE INDEX temp_ttmm_geom_idx ON jcm2.ttmm USING gist(geom);

-- 3.2. Insertar Edificios (dentro del buffer de 500m)
-- Se corrigen valores negativos, se mapea el uso de dominio y se filtran geometrías < 0.5m2 preventivamente.
INSERT INTO jcm2.building (gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom)
SELECT b.gml_id, 
       b.currentuse, -- Preservar el valor original indexado para uso interno
       CASE 
           WHEN b.currentuse = '1_residential' THEN 'residential'
           WHEN b.currentuse = '2_agriculture' THEN 'agriculture'
           WHEN b.currentuse = '3_industrial' THEN 'industrial'
           WHEN b.currentuse = '4_2_retail' THEN 'commerceAndServices'
           WHEN b.currentuse = '4_3_publicServices' THEN 'publicServices'
           WHEN b.currentuse = '4_1_office' THEN 'office'
           ELSE NULL
       END,
       GREATEST(0, b.numberofbuildingunits), 
       GREATEST(0, b.value),
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(b.geom, 25830))))
FROM jcm1.building b, jcm2.ttmm m
WHERE ST_DWithin(b.geom, m.geom, 500)
  AND b.geom IS NOT NULL
  AND ST_Area(ST_Force2D(ST_MakeValid(ST_Transform(b.geom, 25830)))) >= 0.5;

-- 3.3. Insertar Partes de Edificios (dentro del buffer de 500m)
-- Se corrigen números de plantas a valores no negativos y se descartan microgeometrías preventivamente.
INSERT INTO jcm2.buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
SELECT bp.gml_id, 
       GREATEST(0, bp.numberoffloorsaboveground), 
       GREATEST(0, bp.numberoffloorsbelowground),
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(bp.geom, 25830))))
FROM jcm1.buildingpart bp, jcm2.ttmm m
WHERE ST_DWithin(bp.geom, m.geom, 500)
  AND bp.geom IS NOT NULL
  AND ST_Area(ST_Force2D(ST_MakeValid(ST_Transform(bp.geom, 25830)))) >= 0.5;

-- 3.4. Insertar Parcelas Catastrales (dentro del buffer de 500m)
-- Se filtran microgeometrías preventivamente.
INSERT INTO jcm2.cadastralparcel (gml_id, areavalue, localid, geom)
SELECT cp.gml_id, cp.areavalue, cp.localid,
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(cp.geom, 25830))))
FROM jcm1.cadastralparcel cp, jcm2.ttmm m
WHERE ST_DWithin(cp.geom, m.geom, 500)
  AND cp.geom IS NOT NULL
  AND ST_Area(ST_Force2D(ST_MakeValid(ST_Transform(cp.geom, 25830)))) >= 0.5;

-- 3.5. Insertar Tramos Viales (dentro del buffer de 500m)
-- Se filtran tramos no simples y micro-tramos (< 0.5m) preventivamente.
INSERT INTO jcm2.tramovial (id_tramo, id_vial, clased, nombre, firmed, geom)
SELECT tv.id_tramo, tv.id_vial, tv.clased, tv.nombre, tv.firmed,
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(tv.geom, 25830))))
FROM jcm1.tramovial tv, jcm2.ttmm m
WHERE ST_Intersects(tv.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))
  AND tv.geom IS NOT NULL
  AND ST_Length(ST_Force2D(ST_MakeValid(ST_Transform(tv.geom, 25830)))) >= 0.5
  AND ST_IsSimple(ST_Force2D(ST_MakeValid(ST_Transform(tv.geom, 25830))));

-- 3.6. Insertar Portales y PKs (dentro del buffer de 500m)
INSERT INTO jcm2.portalpk (id_tramo, id_vial, id_porpk, numero, geom)
SELECT pk.id_tramo, pk.id_vial, pk.id_porpk, pk.numero,
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(pk.geom, 25830))))
FROM jcm1.portalpk pk, jcm2.ttmm m
WHERE ST_Intersects(pk.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))
  AND pk.geom IS NOT NULL;

-- 3.7. Insertar Tramos de Cursos de Agua (dentro del buffer de 500m)
-- Se filtran micro-cursos (< 0.5m) preventivamente.
INSERT INTO jcm2.tramocurso (id_curso, nombre, tipo_curso, geom)
SELECT tc.id_curso, tc.nombre, tc.tipo_curso,
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(tc.geom, 25830))))
FROM jcm1.tramocurso tc, jcm2.ttmm m
WHERE ST_Intersects(tc.geom, ST_Transform(ST_Buffer(m.geom, 500), 4258))
  AND tc.geom IS NOT NULL
  AND ST_Length(ST_Force2D(ST_MakeValid(ST_Transform(tc.geom, 25830)))) >= 0.5;

-- 3.8. Insertar Polígonos de SIOSE (dentro del buffer de 500m)
-- Se filtran microgeometrías y valores huérfanos de claves foráneas preventivamente.
INSERT INTO jcm2.siose_pol (id_polygon, codiige, hilucs, geom)
SELECT s.id_polygon, s.codiige, s.hilucs,
       ST_Multi(ST_Force2D(ST_MakeValid(ST_Transform(s.geom, 25830))))
FROM jcm1.siose_pol s, jcm2.ttmm m
WHERE ST_DWithin(s.geom, m.geom, 500)
  AND s.geom IS NOT NULL
  AND ST_Area(ST_Force2D(ST_MakeValid(ST_Transform(s.geom, 25830)))) >= 0.5
  AND s.codiige IN (SELECT codiige FROM jcm1.siose_codiige)
  AND s.hilucs IN (SELECT hilucs FROM jcm1.siose_hilucs);

-- Eliminar índice temporal
DROP INDEX IF EXISTS jcm2.temp_ttmm_geom_idx;

-- 3.9. Copiar Tablas Alfanuméricas SIOSE
-- Se realiza después del insert de siose_pol para mantener la consistencia
CREATE TABLE jcm2.siose_codiige AS SELECT * FROM jcm1.siose_codiige;
CREATE TABLE jcm2.siose_hilucs AS SELECT * FROM jcm1.siose_hilucs;


-- 4. VALIDACIÓN Y CORRECCIÓN GEOMÉTRICA (ST_MakeValid)
-- ============================================================================
-- NOTA: Sección vacía para compatibilidad de logs. La validación se realiza 
-- de manera preventiva durante la inserción mediante ST_MakeValid directo.


-- 5. CREACIÓN DE ÍNDICES DEFINITIVOS
-- ============================================================================
CREATE INDEX jcm2_ttmm_geom_idx ON jcm2.ttmm USING gist(geom);
CREATE INDEX jcm2_building_geom_idx ON jcm2.building USING gist(geom);
CREATE INDEX jcm2_buildingpart_geom_idx ON jcm2.buildingpart USING gist(geom);
CREATE INDEX jcm2_cadastralparcel_geom_idx ON jcm2.cadastralparcel USING gist(geom);
CREATE INDEX jcm2_tramovial_geom_idx ON jcm2.tramovial USING gist(geom);
CREATE INDEX jcm2_portalpk_geom_idx ON jcm2.portalpk USING gist(geom);
CREATE INDEX jcm2_tramocurso_geom_idx ON jcm2.tramocurso USING gist(geom);
CREATE INDEX jcm2_siose_pol_geom_idx ON jcm2.siose_pol USING gist(geom);

-- Índice de atributo para el uso de edificios (tanto original como INSPIRE)
CREATE INDEX jcm2_building_currentuse_idx ON jcm2.building (currentuse);
CREATE INDEX jcm2_building_current_use_in_idx ON jcm2.building (current_use_in);


-- 5.9. LIMPIEZA PREVENTIVA ANTES DE LAS RESTRICCIONES (CONSTRAINTS)
-- ============================================================================
-- NOTA: Sección vacía para compatibilidad de logs. La limpieza se realiza 
-- de manera preventiva y proactiva durante la fase 3 de inserción de datos.


-- 6. ADICIÓN DE RESTRICCIONES (CONSTRAINTS) SEMÁNTICAS Y GEOMÉTRICAS
-- ============================================================================

-- 6.1. Restricciones de Geometría Válida (ST_IsValid)
ALTER TABLE jcm2.ttmm ADD CONSTRAINT chk_ttmm_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.tramocurso ADD CONSTRAINT chk_tramocurso_geom_valid CHECK (ST_IsValid(geom));
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_valid CHECK (ST_IsValid(geom));

-- 6.2. Restricción de Elementos de Red Lineales Simples (ST_IsSimple)
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_simple CHECK (ST_IsSimple(geom));

-- 6.3. Restricciones de Dimensiones Mínimas Admisibles (Escala 1:5000)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.cadastralparcel ADD CONSTRAINT chk_cadastralparcel_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT chk_siose_pol_geom_area CHECK (ST_Area(geom) >= 0.5);
ALTER TABLE jcm2.tramovial ADD CONSTRAINT chk_tramovial_geom_length CHECK (ST_Length(geom) >= 0.5);
ALTER TABLE jcm2.tramocurso ADD CONSTRAINT chk_tramocurso_geom_length CHECK (ST_Length(geom) >= 0.5);

-- 6.4. Restricciones de Campos Alfanuméricos Positivos
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_units CHECK (numberofbuildingunits >= 0);
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_value CHECK (value >= 0);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_up CHECK (numberoffloorsaboveground >= 0);
ALTER TABLE jcm2.buildingpart ADD CONSTRAINT chk_buildingpart_floors_down CHECK (numberoffloorsbelowground >= 0);

-- 6.5. Restricción de Dominio Acotado para currentuse (INSPIRE)
ALTER TABLE jcm2.building ADD CONSTRAINT chk_building_currentuse CHECK (
    currentuse IN (
        'residential', 'agriculture', 'industrial', 'commerceAndServices', 
        'publicServices', 'office', 'educational', 'health', 
        'recreational', 'other', 'ancillary'
    ) OR currentuse IS NULL
);

-- 6.6. Configuración de Claves Primarias y Foráneas en SIOSE
-- Establecer Claves Primarias en tablas alfanuméricas auxiliares
ALTER TABLE jcm2.siose_codiige ADD CONSTRAINT pk_siose_codiige PRIMARY KEY (codiige);
ALTER TABLE jcm2.siose_hilucs ADD CONSTRAINT pk_siose_hilucs PRIMARY KEY (hilucs);

-- Establecer Claves Foráneas de integridad referencial
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_codiige FOREIGN KEY (codiige) REFERENCES jcm2.siose_codiige(codiige);
ALTER TABLE jcm2.siose_pol ADD CONSTRAINT fk_siose_pol_hilucs FOREIGN KEY (hilucs) REFERENCES jcm2.siose_hilucs(hilucs);

