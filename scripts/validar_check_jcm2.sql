-- ============================================================================
-- PRUEBAS UNITARIAS DE VIOLACIÓN DE RESTRICCIONES (CONSTRAINTS) EN jcm2
-- Cada consulta está diseñada para fallar y ser atrapada por el wrapper de Python.
-- ============================================================================

-- TEST 1: chk_building_units (Unidades de edificación negativas)
-- [EXPECTED_ERROR] chk_building_units
INSERT INTO jcm2.building (gml_id, currentuse, numberofbuildingunits, value, geom)
VALUES ('TEST_UNITS_NEG', 'residential', -5, 100000, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 2: chk_building_value (Valor catastral negativo)
-- [EXPECTED_ERROR] chk_building_value
INSERT INTO jcm2.building (gml_id, currentuse, numberofbuildingunits, value, geom)
VALUES ('TEST_VALUE_NEG', 'residential', 1, -1500, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 3: chk_building_currentuse (Dominio actual de uso incorrecto)
-- [EXPECTED_ERROR] chk_building_currentuse
INSERT INTO jcm2.building (gml_id, currentuse, numberofbuildingunits, value, geom)
VALUES ('TEST_USE_INVALID', 'uso_no_existente_inspire', 1, 50000, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 4: chk_buildingpart_floors_up (Plantas sobre rasante negativas)
-- [EXPECTED_ERROR] chk_buildingpart_floors_up
INSERT INTO jcm2.buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
VALUES ('TEST_FLOORS_UP_NEG', -2, 0, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 5: chk_buildingpart_floors_down (Plantas bajo rasante negativas)
-- [EXPECTED_ERROR] chk_buildingpart_floors_down
INSERT INTO jcm2.buildingpart (gml_id, numberoffloorsaboveground, numberoffloorsbelowground, geom)
VALUES ('TEST_FLOORS_DOWN_NEG', 2, -1, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));

-- TEST 6: chk_building_geom_area (Geometría de área microscópica < 0.5 m2)
-- [EXPECTED_ERROR] chk_building_geom_area
INSERT INTO jcm2.building (gml_id, currentuse, numberofbuildingunits, value, geom)
VALUES ('TEST_AREA_MICRO', 'residential', 1, 20000, ST_GeomFromText('MULTIPOLYGON(((0 0, 0.5 0, 0.5 0.5, 0 0.5, 0 0)))', 25830));

-- TEST 7: chk_tramovial_geom_simple (Geometría de línea no simple / con lazo)
-- [EXPECTED_ERROR] chk_tramovial_geom_simple
INSERT INTO jcm2.tramovial (id_tramo, id_vial, clased, nombre, firmed, geom)
VALUES ('TEST_LINE_NON_SIMPLE', 'VIAL_999', 'Calle', 'Calle Lazo', 'Pavimentado', 
ST_GeomFromText('MULTILINESTRING((0 0, 10 0, 5 5, 5 -5, 0 0))', 25830));

-- TEST 8: chk_building_geom_valid (Geometría de polígono inválido / auto-intersectante)
-- [EXPECTED_ERROR] chk_building_geom_valid
INSERT INTO jcm2.building (gml_id, currentuse, numberofbuildingunits, value, geom)
VALUES ('TEST_GEOM_INVALID', 'residential', 1, 15000, 
ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 5 12, 10 10, 0 10, 0 0)))', 25830));

-- TEST 9: fk_siose_pol_codiige (Integridad referencial: código de cobertura inexistente)
-- [EXPECTED_ERROR] fk_siose_pol_codiige
INSERT INTO jcm2.siose_pol (id_polygon, codiige, hilucs, geom)
VALUES ('TEST_SIOSE_FK_CODIIGE', 99999, 110, ST_GeomFromText('MULTIPOLYGON(((0 0, 10 0, 10 10, 0 10, 0 0)))', 25830));
