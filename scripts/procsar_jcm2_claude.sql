-- ============================================================================
-- PROCESAMIENTO DE CAPA: building  (jcm1 → jcm2)
-- Proyecto Final: Bases de Datos Espaciales
-- ============================================================================
-- PARÁMETROS DE PLANTILLA (sustituidos por Python antes de ejecutar):
--   {{SRID_ORIGEN}}    → SRID de jcm1.building  (ej. 4258)
--   {{SRID_PROYECTO}}  → SRID de jcm2            (ej. 25830)
-- ============================================================================
-- CONVENCIONES DE CATEGORÍAS EN EL LOG:
--
--   originales_validas        → ST_IsValid en SRS final = true  (sin corrección)
--   originales_invalidas      → ST_IsValid en SRS final = false (necesitan MakeValid)
--   reparadas_exito           → estaban inválidas, MakeValid las dejó válidas y no vacías
--   corruptas_descartadas     → MakeValid no pudo producir geometría válida y no vacía
--   filtradas_conversion_2d   → válidas tras MakeValid, pero Force2D/Multi las rompió
--   filtradas_escala          → superaron todo lo anterior pero ST_Area < umbral
--
-- Las categorías son MUTUAMENTE EXCLUYENTES: una fila cuenta en exactamente una.
-- total_origen_buffer = sum de las seis categorías anteriores.
-- insertadas_destino  = reparadas_exito + originales_validas - filtradas_conversion_2d
--                       - filtradas_escala  (calculado a posteriori para verificación)
-- ============================================================================


-- ============================================================================
-- SECCIÓN 0 · TABLA DE LOG (crear una sola vez para todo el proyecto)
-- Si ya existe de ejecuciones anteriores, se limpia la entrada de 'building'
-- para permitir re-ejecuciones idempotentes sin duplicar métricas.
-- ============================================================================

CREATE TABLE IF NOT EXISTS jcm2.log_calidad_geometrias (
    id                      serial PRIMARY KEY,
    tabla                   varchar(64)  NOT NULL,
    ts_proceso              timestamptz  NOT NULL DEFAULT now(),
    srid_origen             integer,
    srid_proyecto           integer,
    total_origen_buffer     integer,
    originales_validas      integer,   -- válidas en SRS final sin corrección
    originales_invalidas    integer,   -- inválidas en SRS final, se intentó MakeValid
    reparadas_exito         integer,   -- inválidas que MakeValid dejó útiles
    corruptas_descartadas   integer,   -- inválidas que MakeValid no pudo salvar
    filtradas_conversion_2d integer,   -- rotas por Force2D/Multi después de ser válidas
    filtradas_escala        integer,   -- descartadas por área < umbral de escala
    insertadas_destino      integer,   -- filas que llegaron a jcm2.building
    notas                   text
);

DELETE FROM jcm2.log_calidad_geometrias WHERE tabla = 'building';


-- ============================================================================
-- SECCIÓN 1 · DDL DE LA TABLA DESTINO
-- ============================================================================

DROP TABLE IF EXISTS jcm2.building CASCADE;

CREATE TABLE jcm2.building (
    gid                    serial PRIMARY KEY,
    gml_id                 varchar,
    current_use_in         varchar,        -- valor bruto de jcm1, para auditoría
    currentuse             varchar,        -- valor normalizado INSPIRE
    numberofbuildingunits  integer,
    value                  integer,
    geom                   geometry(MultiPolygon, {{SRID_PROYECTO}})
);


-- ============================================================================
-- SECCIÓN 2 · PROCESAMIENTO EN CTE: UNA SOLA PASADA SOBRE LOS DATOS
--
-- Cada CTE añade exactamente una capa de información a la anterior.
-- Ninguna geometría se transforma ni se evalúa más de una vez.
-- La CTE final es la fuente única de verdad para el INSERT y el log.
-- ============================================================================

WITH

-- ----------------------------------------------------------------------------
-- CTE 1: FILTRO ESPACIAL
-- Se transforma b.geom al SRS del proyecto ANTES del DWithin para que
-- la distancia de 500 m se interprete en metros, no en grados.
-- Se descarta geom IS NULL aquí para no arrastrar NULLs al resto de CTEs.
-- El CROSS JOIN LATERAL garantiza que m.geom se evalúa una sola vez (escalar).
-- ----------------------------------------------------------------------------
candidatos AS (
    SELECT
        b.gml_id,
        b.currentuse                              AS current_use_in,
        b.numberofbuildingunits                   AS units_raw,
        b.value                                   AS value_raw,
        ST_Transform(b.geom, {{SRID_PROYECTO}})   AS geom_proj   -- reproyección única
    FROM jcm1.building b
    CROSS JOIN LATERAL (
        SELECT ST_Union(geom) AS geom          -- une todos los polígonos de ttmm en uno
        FROM jcm2.ttmm
    ) m
    WHERE b.geom IS NOT NULL
      AND ST_DWithin(
              ST_Transform(b.geom, {{SRID_PROYECTO}}),
              m.geom,
              500
          )
),

-- ----------------------------------------------------------------------------
-- CTE 2: EVALUACIÓN DE VALIDEZ EN EL SRS FINAL
-- La validez se comprueba DESPUÉS de reproyectar, que es el único momento
-- relevante: una geometría puede ser válida en 4258 e inválida en 25830.
-- ----------------------------------------------------------------------------
validados AS (
    SELECT
        *,
        ST_IsValid(geom_proj) AS valida_en_proj
    FROM candidatos
),

-- ----------------------------------------------------------------------------
-- CTE 3: CORRECCIÓN SELECTIVA (MakeValid solo donde hace falta)
-- Las válidas pasan sin tocar. Las inválidas reciben MakeValid.
-- El resultado se almacena en geom_corr para la siguiente etapa.
-- ----------------------------------------------------------------------------
corregidos AS (
    SELECT
        *,
        CASE
            WHEN valida_en_proj THEN geom_proj
            ELSE ST_MakeValid(geom_proj)
        END AS geom_corr
    FROM validados
),

-- ----------------------------------------------------------------------------
-- CTE 4: RE-EVALUACIÓN POST-CORRECCIÓN
-- Se determina si MakeValid produjo algo aprovechable.
-- Se categoriza la causa de descarte para el log.
-- ----------------------------------------------------------------------------
evaluados AS (
    SELECT
        *,
        ST_IsValid(geom_corr)  AS valida_post_corr,
        ST_IsEmpty(geom_corr)  AS vacia_post_corr
    FROM corregidos
),

-- ----------------------------------------------------------------------------
-- CTE 5: CONVERSIÓN 2D Y ENCAPSULADO MULTI
-- Solo se aplica a filas que son válidas y no vacías.
-- Se verifica que Force2D/Multi no corrompa la geometría resultante.
-- ----------------------------------------------------------------------------
convertidos AS (
    SELECT
        *,
        CASE
            WHEN valida_post_corr AND NOT vacia_post_corr
            THEN ST_Multi(ST_Force2D(geom_corr))
            ELSE NULL
        END AS geom_final
    FROM evaluados
),

-- ----------------------------------------------------------------------------
-- CTE 6: CLASIFICACIÓN FINAL MUTUAMENTE EXCLUYENTE
-- Cada fila recibe exactamente una etiqueta de resultado.
-- Orden de precedencia: corrupta > vacia > rota_conversion > escala > válida
-- ----------------------------------------------------------------------------
clasificados AS (
    SELECT
        gml_id,
        current_use_in,
        -- Mapeo INSPIRE en el último momento, sobre datos ya saneados
        CASE current_use_in
            WHEN '1_residential'       THEN 'residential'
            WHEN '2_agriculture'       THEN 'agriculture'
            WHEN '3_industrial'        THEN 'industrial'
            WHEN '4_2_retail'          THEN 'commerceAndServices'
            WHEN '4_3_publicServices'  THEN 'publicServices'
            WHEN '4_1_office'          THEN 'office'
            WHEN '5_educational'       THEN 'educational'
            WHEN '6_health'            THEN 'health'
            WHEN '7_recreational'      THEN 'recreational'
            WHEN '8_other'             THEN 'other'
            WHEN '9_ancillary'         THEN 'ancillary'
            ELSE NULL   -- valor desconocido: pasa como NULL, registrado en current_use_in
        END                                                    AS currentuse,
        -- Corrección de valores negativos/nulos en atributos numéricos
        -- COALESCE garantiza que NULL en origen se trate explícitamente como 0
        COALESCE(GREATEST(0, units_raw), 0)                   AS numberofbuildingunits,
        COALESCE(GREATEST(0, value_raw), 0)                   AS value,
        geom_final,
        -- --- Flags de clasificación para el log ---
        valida_en_proj,
        -- Corrupta: inválida en origen Y MakeValid no la salvó
        (NOT valida_en_proj
            AND (NOT valida_post_corr OR vacia_post_corr))     AS es_corrupta,
        -- Rota por conversión: era válida tras MakeValid pero Force2D/Multi la rompió
        (valida_post_corr
            AND NOT vacia_post_corr
            AND (geom_final IS NULL OR NOT ST_IsValid(geom_final)
                 OR ST_IsEmpty(geom_final)))                   AS es_rota_conversion,
        -- Filtrada por escala: pasó todo pero área insuficiente
        (valida_post_corr
            AND NOT vacia_post_corr
            AND geom_final IS NOT NULL
            AND ST_IsValid(geom_final)
            AND NOT ST_IsEmpty(geom_final)
            AND ST_Area(geom_final) < 0.5)                    AS es_filtrada_escala,
        -- Apta: supera todos los filtros
        (valida_post_corr
            AND NOT vacia_post_corr
            AND geom_final IS NOT NULL
            AND ST_IsValid(geom_final)
            AND NOT ST_IsEmpty(geom_final)
            AND ST_Area(geom_final) >= 0.5)                   AS es_apta
    FROM convertidos
),

-- ----------------------------------------------------------------------------
-- CTE 7: INSERT AL DESTINO (usando INSERT ... SELECT dentro de CTE con
-- la cláusula RETURNING para contar las filas insertadas en el log).
-- En PostgreSQL esto requiere un CTE de escritura (writable CTE).
-- ----------------------------------------------------------------------------
insertadas AS (
    INSERT INTO jcm2.building
        (gml_id, current_use_in, currentuse, numberofbuildingunits, value, geom)
    SELECT
        gml_id,
        current_use_in,
        currentuse,
        numberofbuildingunits,
        value,
        geom_final
    FROM clasificados
    WHERE es_apta
    RETURNING gid   -- solo necesitamos contar
),

-- ----------------------------------------------------------------------------
-- CTE 8: MÉTRICAS PARA EL LOG (agregadas desde clasificados, no desde destino)
-- ----------------------------------------------------------------------------
metricas AS (
    SELECT
        COUNT(*)                                        AS total_origen_buffer,
        COUNT(*) FILTER (WHERE valida_en_proj)          AS originales_validas,
        COUNT(*) FILTER (WHERE NOT valida_en_proj)      AS originales_invalidas,
        COUNT(*) FILTER (
            WHERE NOT valida_en_proj
              AND NOT es_corrupta
              AND NOT es_rota_conversion
              AND NOT es_filtrada_escala)               AS reparadas_exito,
        COUNT(*) FILTER (WHERE es_corrupta)             AS corruptas_descartadas,
        COUNT(*) FILTER (WHERE es_rota_conversion)      AS filtradas_conversion_2d,
        COUNT(*) FILTER (WHERE es_filtrada_escala)      AS filtradas_escala,
        (SELECT COUNT(*) FROM insertadas)               AS insertadas_destino
    FROM clasificados
)

-- ----------------------------------------------------------------------------
-- INSERT FINAL AL LOG
-- ----------------------------------------------------------------------------
INSERT INTO jcm2.log_calidad_geometrias (
    tabla,
    ts_proceso,
    srid_origen,
    srid_proyecto,
    total_origen_buffer,
    originales_validas,
    originales_invalidas,
    reparadas_exito,
    corruptas_descartadas,
    filtradas_conversion_2d,
    filtradas_escala,
    insertadas_destino,
    notas
)
SELECT
    'building',
    now(),
    {{SRID_ORIGEN}},
    {{SRID_PROYECTO}},
    total_origen_buffer,
    originales_validas,
    originales_invalidas,
    reparadas_exito,
    corruptas_descartadas,
    filtradas_conversion_2d,
    filtradas_escala,
    insertadas_destino,
    -- Nota automática si hay valores CASE no mapeados
    CASE
        WHEN EXISTS (
            SELECT 1 FROM jcm2.building
            WHERE current_use_in IS NOT NULL AND currentuse IS NULL
        )
        THEN 'ADVERTENCIA: existen valores de current_use_in sin mapeo INSPIRE. Revisar columna current_use_in en jcm2.building.'
        ELSE NULL
    END
FROM metricas;


-- ============================================================================
-- SECCIÓN 3 · ÍNDICES
-- Se crean DESPUÉS del INSERT para aprovechar el algoritmo de construcción
-- bulk (más eficiente que actualización incremental fila a fila).
-- ============================================================================

CREATE INDEX jcm2_building_geom_idx
    ON jcm2.building USING gist(geom);

CREATE INDEX jcm2_building_currentuse_idx
    ON jcm2.building (currentuse);

CREATE INDEX jcm2_building_current_use_in_idx
    ON jcm2.building (current_use_in);

-- Actualiza las estadísticas del planificador tras la carga
ANALYZE jcm2.building;


-- ============================================================================
-- SECCIÓN 4 · CONSTRAINTS
-- Se añaden DESPUÉS del INSERT + ANALYZE para que PostgreSQL pueda validar
-- con el planificador informado. Se usa NOT VALID + VALIDATE separados
-- para no bloquear la tabla más tiempo del necesario.
-- ============================================================================

-- 4.1. Geometría válida
ALTER TABLE jcm2.building
    ADD CONSTRAINT chk_building_geom_valid
    CHECK (ST_IsValid(geom)) NOT VALID;
ALTER TABLE jcm2.building
    VALIDATE CONSTRAINT chk_building_geom_valid;

-- 4.2. Área mínima de escala 1:5000
ALTER TABLE jcm2.building
    ADD CONSTRAINT chk_building_geom_area
    CHECK (ST_Area(geom) >= 0.5) NOT VALID;
ALTER TABLE jcm2.building
    VALIDATE CONSTRAINT chk_building_geom_area;

-- 4.3. Atributos numéricos no negativos
ALTER TABLE jcm2.building
    ADD CONSTRAINT chk_building_units
    CHECK (numberofbuildingunits >= 0) NOT VALID;
ALTER TABLE jcm2.building
    VALIDATE CONSTRAINT chk_building_units;

ALTER TABLE jcm2.building
    ADD CONSTRAINT chk_building_value
    CHECK (value >= 0) NOT VALID;
ALTER TABLE jcm2.building
    VALIDATE CONSTRAINT chk_building_value;

-- 4.4. Dominio INSPIRE para currentuse
--      NULL permitido: edificios con uso no mapeado quedan registrados
--      en current_use_in para auditoría posterior.
ALTER TABLE jcm2.building
    ADD CONSTRAINT chk_building_currentuse
    CHECK (
        currentuse IN (
            'residential', 'agriculture', 'industrial',
            'commerceAndServices', 'publicServices', 'office',
            'educational', 'health', 'recreational', 'other', 'ancillary'
        ) OR currentuse IS NULL
    ) NOT VALID;
ALTER TABLE jcm2.building
    VALIDATE CONSTRAINT chk_building_currentuse;


-- ============================================================================
-- SECCIÓN 5 · VERIFICACIÓN DE CONSISTENCIA DEL LOG
-- Comprueba que la suma de categorías cuadra con el total.
-- Si no cuadra, lanza un error explícito (no silencioso).
-- ============================================================================

DO $$
DECLARE
    r jcm2.log_calidad_geometrias%ROWTYPE;
    suma_categorias integer;
BEGIN
    SELECT * INTO r
    FROM jcm2.log_calidad_geometrias
    WHERE tabla = 'building'
    ORDER BY ts_proceso DESC
    LIMIT 1;

    suma_categorias :=
        COALESCE(r.originales_validas,      0)
      + COALESCE(r.corruptas_descartadas,   0)
      + COALESCE(r.filtradas_conversion_2d, 0)
      + COALESCE(r.filtradas_escala,        0)
      -- reparadas_exito son un subconjunto de originales_invalidas, no se suman
      -- las inválidas que SÍ se repararon están en originales_invalidas - corruptas
      -- El total se cierra con: validas + (invalidas - corruptas) - conv - escala
      + COALESCE(
            r.originales_invalidas
          - r.corruptas_descartadas
          - r.filtradas_conversion_2d
          - r.filtradas_escala,
          0);

    -- El total debe coincidir
    IF r.total_origen_buffer IS DISTINCT FROM suma_categorias THEN
        RAISE EXCEPTION
            'LOG INCONSISTENTE para building: total_origen_buffer=% ≠ suma_categorias=%',
            r.total_origen_buffer, suma_categorias;
    END IF;

    -- Las insertadas deben coincidir con las aptas
    IF r.insertadas_destino IS DISTINCT FROM
       (r.total_origen_buffer
        - COALESCE(r.corruptas_descartadas,   0)
        - COALESCE(r.filtradas_conversion_2d, 0)
        - COALESCE(r.filtradas_escala,        0)) THEN
        RAISE EXCEPTION
            'LOG INCONSISTENTE para building: insertadas_destino=% no cuadra con categorías de descarte',
            r.insertadas_destino;
    END IF;

    RAISE NOTICE 'building · % filas procesadas → % insertadas · % reparadas · % descartadas',
        r.total_origen_buffer,
        r.insertadas_destino,
        r.reparadas_exito,
        COALESCE(r.corruptas_descartadas, 0)
          + COALESCE(r.filtradas_conversion_2d, 0)
          + COALESCE(r.filtradas_escala, 0);
END;
$$;