-- ============================================================================
-- SCRIPT DE CREACIÓN CONDICIONAL DE VISTAS DE AUDITORÍA Y CONTROL DE CALIDAD
-- ============================================================================

DO $$
DECLARE
    v_rec RECORD;
    view_name varchar;
    key_col varchar;
BEGIN
    -- 1. Dropear todas las vistas de calidad previas en el esquema jcm2
    FOR v_rec IN 
        SELECT viewname 
        FROM pg_views 
        WHERE schemaname = 'jcm2' 
          AND (viewname LIKE 'v_log_%' OR viewname LIKE 'v_reparado_destino_%')
    LOOP
        EXECUTE 'DROP VIEW IF EXISTS jcm2.' || quote_ident(v_rec.viewname) || ' CASCADE';
        RAISE NOTICE 'Drop preventivo de vista: jcm2.%', v_rec.viewname;
    END LOOP;

    -- 2. Crear vistas de descartes específicas por motivo y tabla si existen registros en el log de auditoría
    FOR v_rec IN 
        SELECT DISTINCT tabla, motivo_descarte 
        FROM jcm2.log_detalle_calidad 
        WHERE motivo_descarte IS NOT NULL
    LOOP
        view_name := 'v_log_' || v_rec.motivo_descarte || '_' || v_rec.tabla;
        EXECUTE format('
            CREATE OR REPLACE VIEW jcm2.%I AS
            SELECT id, gml_id, srid_original, es_valida_original, valida_post_corr, vacia_post_corr, motivo_descarte, geom_original AS geom
            FROM jcm2.log_detalle_calidad
            WHERE tabla = %L AND motivo_descarte = %L', 
            view_name, v_rec.tabla, v_rec.motivo_descarte);
        RAISE NOTICE 'Vista de descarte creada: jcm2.%', view_name;
    END LOOP;

    -- 3. Crear vistas de geometrías originales no válidas y sus reparadas correspondientes
    FOR v_rec IN 
        SELECT DISTINCT tabla 
        FROM jcm2.log_detalle_calidad 
        WHERE NOT es_valida_original
    LOOP
        -- Vista de no válidas originales
        view_name := 'v_log_invalido_original_' || v_rec.tabla;
        EXECUTE format('
            CREATE OR REPLACE VIEW jcm2.%I AS
            SELECT id, gml_id, srid_original, es_valida_original, geom_original AS geom
            FROM jcm2.log_detalle_calidad
            WHERE tabla = %L AND NOT es_valida_original', 
            view_name, v_rec.tabla);
        RAISE NOTICE 'Vista de inválidos de origen creada: jcm2.%', view_name;

        -- Determinar columna clave según la tabla en jcm2
        key_col := CASE v_rec.tabla
            WHEN 'building' THEN 'gml_id'
            WHEN 'buildingpart' THEN 'gml_id'
            WHEN 'cadastralparcel' THEN 'gml_id'
            WHEN 'tramovial' THEN 'id_tramo'
            WHEN 'portalpk' THEN 'id_porpk'
            WHEN 'tramocurso' THEN 'id_curso'
            WHEN 'siose_pol' THEN 'id_polygon'
            WHEN 'ttmm' THEN 'inspireid'
            WHEN 'municipio' THEN 'inspireid'
            ELSE 'gml_id'
        END;

        -- Vista de reparadas en destino
        view_name := 'v_reparado_destino_' || v_rec.tabla;
        EXECUTE format('
            CREATE OR REPLACE VIEW jcm2.%I AS
            SELECT * 
            FROM jcm2.%I
            WHERE %I IN (
                SELECT gml_id 
                FROM jcm2.log_detalle_calidad 
                WHERE tabla = %L AND NOT es_valida_original AND valida_post_corr AND NOT vacia_post_corr
            )', 
            view_name, v_rec.tabla, key_col, v_rec.tabla);
        RAISE NOTICE 'Vista de reparados en destino creada: jcm2.%', view_name;
    END LOOP;
END;
$$;
