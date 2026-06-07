-- ============================================================================
-- PRUEBAS UNITARIAS DE VIOLACIÓN DE RESTRICCIONES (CONSTRAINTS) EN jcm3
-- Cada consulta está diseñada para fallar y ser atrapada por el wrapper de Python.
-- ============================================================================

-- TEST 1: municipio_inspireid_null (inspireid nulo en municipio)
-- [EXPECTED_ERROR] inspireid
INSERT INTO jcm3.municipio (inspireid, natcode, nameunit, geom)
VALUES (NULL, '340101', 'TestMunicipio', ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 2: municipio_inspireid_key (inspireid duplicado en municipio)
-- [EXPECTED_ERROR] municipio_inspireid_key
INSERT INTO jcm3.municipio (inspireid, natcode, nameunit, geom)
VALUES ('MUN_TEST_DUP', '340101', 'TestMunicipio1', ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));
INSERT INTO jcm3.municipio (inspireid, natcode, nameunit, geom)
VALUES ('MUN_TEST_DUP', '340102', 'TestMunicipio2', ST_GeomFromText('MULTIPOLYGON(((10 10, 20 10, 20 20, 10 20, 10 10)))', 25830));

-- TEST 3: building_gml_id_null (gml_id nulo en building)
-- [EXPECTED_ERROR] gml_id
INSERT INTO jcm3.building (gml_id, currentuse, geom)
VALUES (NULL, 'residential', ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 4: building_geom_null (geometría nula en building)
-- [EXPECTED_ERROR] geom
INSERT INTO jcm3.building (gml_id, currentuse, geom)
VALUES ('BLDG_TEST_GEOM_NULL', 'residential', NULL);

-- TEST 5: CP_areavalue_check (areavalue no positivo en cadastralparcel)
-- [EXPECTED_ERROR] cadastralparcel_areavalue_check
INSERT INTO jcm3.cadastralparcel (gml_id, areavalue, geom)
VALUES ('CP_TEST_AREA_NEG', -1.5, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 6: tramovial_id_tramo_key (id_tramo duplicado en tramovial)
-- [EXPECTED_ERROR] tramovial_id_tramo_key
INSERT INTO jcm3.tramovial (id_tramo, id_vial, geom)
VALUES ('TRAMO_TEST_DUP', 'VIAL_1', ST_GeomFromText('MULTILINESTRING((0 0, 10 10))', 25830));
INSERT INTO jcm3.tramovial (id_tramo, id_vial, geom)
VALUES ('TRAMO_TEST_DUP', 'VIAL_2', ST_GeomFromText('MULTILINESTRING((10 10, 20 20))', 25830));

-- TEST 7: portalpk_numero_null (numero nulo en portalpk)
-- [EXPECTED_ERROR] numero
INSERT INTO jcm3.portalpk (id_tramo, id_vial, id_porpk, numero, geom)
VALUES ('TRAMO_1', 'VIAL_1', 'PORTAL_TEST_NUM_NULL', NULL, ST_GeomFromText('MULTIPOINT((0 0))', 25830));
