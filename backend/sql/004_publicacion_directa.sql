-- =========================================================
-- MIGRACIÓN 004 · PUBLICACIÓN DIRECTA (sin aprobación de la Junta)
-- Base: sihaychamba (MySQL 8 o MariaDB 10.6+). Ejecutar con una cuenta administradora (root),
-- DESPUÉS de bd_sihaychamba.sql y sql/extension_sihaychamba.sql.
--
-- ANTES: respaldo completo fuera de la base (recomendado):
--   mysqldump -h 127.0.0.1 -P 3308 -u root -p --routines --triggers sihaychamba > respaldo_pre_004.sql
-- Además, esta migración copia publicacion en respaldo_004_publicacion.
--
-- Es re-ejecutable: no borra tablas ni datos. Reversión: 004_publicacion_directa_rollback.sql
--
--   1. migracion_esquema ........ registro de versiones aplicadas
--   2. publicacion.fecha_publicacion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
--      (fechas existentes recuperadas del historial de auditoría)
--   3. idx_publicacion_recientes  orden del catálogo
--   4. trg_publicacion_auditar_ai/au  también auditan fecha_publicacion
--   5. sp_crear_publicacion ...... creación directa, atómica y validada
--   6. Retira sp_crear_solicitud_publicacion, sp_aprobar_solicitud_publicacion
--      y sp_rechazar_solicitud_publicacion (exclusivos del flujo de aprobación).
--      Se CONSERVAN solicitud_publicacion, sus triggers y vw_solicitudes_publicacion
--      como historial de solo lectura (publicacion.id_solicitud_origen los referencia).
--   7. vw_publicaciones_vigentes incluye fecha_publicacion
--   8. Permisos mínimos para r_tc_backend (si el rol existe)
-- =========================================================
USE sihaychamba;
-- Workbench usa «safe update mode» (error 1175 en el UPDATE ... JOIN de fechas).
-- Se desactiva solo en esta sesión y al final se restaura el valor que tenías.
SET @sh_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;

CREATE TABLE IF NOT EXISTS migracion_esquema (
    version VARCHAR(20) NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    aplicada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_migracion_esquema PRIMARY KEY (version)
) ENGINE=InnoDB;

-- Respaldo de la tabla que se altera (solo la primera vez: IF NOT EXISTS no vuelve a copiar).
CREATE TABLE IF NOT EXISTS respaldo_004_publicacion AS SELECT * FROM publicacion;

DELIMITER $$

-- Ejecuta DDL solo si hace falta (MySQL 8 no admite ADD COLUMN / CREATE INDEX IF NOT EXISTS).
DROP PROCEDURE IF EXISTS mig004_ddl$$
CREATE PROCEDURE mig004_ddl(IN p_aplicar BOOLEAN, IN p_sql TEXT)
BEGIN
    IF p_aplicar THEN
        SET @mig004_sql = p_sql;
        PREPARE s FROM @mig004_sql;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;
END$$

DELIMITER ;

-- =========================================================
-- 2. fecha_publicacion (nace NULL para poder recuperar las fechas históricas)
-- =========================================================
SET @mig004_falta = NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'publicacion' AND COLUMN_NAME = 'fecha_publicacion');
CALL mig004_ddl(@mig004_falta, 'ALTER TABLE publicacion ADD COLUMN fecha_publicacion DATETIME NULL AFTER activa');

-- =========================================================
-- 4. Auditoría de publicacion con fecha_publicacion
-- (se recrea antes de recuperar fechas para que el historial registre el cambio)
-- =========================================================
DELIMITER $$

DROP TRIGGER IF EXISTS trg_publicacion_auditar_ai$$
CREATE TRIGGER trg_publicacion_auditar_ai
AFTER INSERT ON publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'CREAR_PUBLICACION',
        CONCAT('publicacion:',NEW.id_publicacion),
        NULL,
        JSON_OBJECT(
            'id_publicacion',NEW.id_publicacion,
            'id_solicitud_origen',NEW.id_solicitud_origen,
            'id_categoria',NEW.id_categoria,
            'id_responsable',NEW.id_responsable,
            'id_metodo_pago',NEW.id_metodo_pago,
            'titulo',NEW.titulo,'descripcion',NEW.descripcion,
            'ubicacion',NEW.ubicacion,
            'disponible_desde',NEW.disponible_desde,
            'disponible_hasta',NEW.disponible_hasta,
            'cantidad',NEW.cantidad,'tipo',NEW.tipo,'activa',NEW.activa,
            'fecha_publicacion',NEW.fecha_publicacion
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_publicacion_auditar_au$$
CREATE TRIGGER trg_publicacion_auditar_au
AFTER UPDATE ON publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_PUBLICACION',
        CONCAT('publicacion:',NEW.id_publicacion),
        JSON_OBJECT(
            'id_categoria',OLD.id_categoria,'id_responsable',OLD.id_responsable,
            'id_metodo_pago',OLD.id_metodo_pago,'titulo',OLD.titulo,
            'descripcion',OLD.descripcion,'ubicacion',OLD.ubicacion,
            'disponible_desde',OLD.disponible_desde,
            'disponible_hasta',OLD.disponible_hasta,
            'cantidad',OLD.cantidad,'tipo',OLD.tipo,'activa',OLD.activa,
            'fecha_publicacion',OLD.fecha_publicacion
        ),
        JSON_OBJECT(
            'id_categoria',NEW.id_categoria,'id_responsable',NEW.id_responsable,
            'id_metodo_pago',NEW.id_metodo_pago,'titulo',NEW.titulo,
            'descripcion',NEW.descripcion,'ubicacion',NEW.ubicacion,
            'disponible_desde',NEW.disponible_desde,
            'disponible_hasta',NEW.disponible_hasta,
            'cantidad',NEW.cantidad,'tipo',NEW.tipo,'activa',NEW.activa,
            'fecha_publicacion',NEW.fecha_publicacion
        )
    );
END$$

DELIMITER ;

-- =========================================================
-- 2b. Recuperar la fecha real de las publicaciones existentes. Fuentes, en orden:
--   a) historial: 'CREAR_PUBLICACION' de esa publicación (fecha exacta del INSERT)
--   b) historial: aprobación de su solicitud de origen (misma transacción que el INSERT)
--   c) RESPALDO DOCUMENTADO: 2000-01-01 00:00:00 → sin rastro histórico; queda al final
--      del catálogo y nunca se confunde con una publicación reciente.
-- Se materializa en una tabla temporal: el trigger de auditoría escribe en
-- historial_gestion y MySQL no permite leerla en la misma sentencia (error 1442).
-- =========================================================
DROP TEMPORARY TABLE IF EXISTS tmp_mig004_fechas;
CREATE TEMPORARY TABLE tmp_mig004_fechas (
    id_publicacion VARCHAR(64) NOT NULL PRIMARY KEY,
    fecha DATETIME NOT NULL,
    origen VARCHAR(40) NOT NULL
);

INSERT INTO tmp_mig004_fechas (id_publicacion, fecha, origen)
SELECT p.id_publicacion,
       COALESCE(a.f, s.f, '2000-01-01 00:00:00'),
       CASE WHEN a.f IS NOT NULL THEN 'historial:CREAR_PUBLICACION'
            WHEN s.f IS NOT NULL THEN 'historial:APROBACION_SOLICITUD'
            ELSE 'respaldo:2000-01-01' END
FROM publicacion p
LEFT JOIN (SELECT SUBSTRING(elemento_afectado, 13) AS id, MIN(fecha) AS f
           FROM historial_gestion
           WHERE accion = 'CREAR_PUBLICACION' AND elemento_afectado LIKE 'publicacion:%'
           GROUP BY elemento_afectado) a ON a.id = p.id_publicacion
LEFT JOIN (SELECT SUBSTRING(elemento_afectado, 23) AS id, MIN(fecha) AS f
           FROM historial_gestion
           WHERE accion = 'ACTUALIZAR_SOLICITUD_PUBLICACION'
             AND elemento_afectado LIKE 'solicitud_publicacion:%'
             AND JSON_UNQUOTE(JSON_EXTRACT(despues, '$.estado')) = 'APROBADA'
           GROUP BY elemento_afectado) s ON s.id = p.id_solicitud_origen
WHERE p.fecha_publicacion IS NULL;

SET @actor_app = 'migracion_004';
UPDATE publicacion p
JOIN tmp_mig004_fechas t ON t.id_publicacion = p.id_publicacion
SET p.fecha_publicacion = t.fecha;
SET @actor_app = NULL;

-- Informe: cuántas fechas salieron de cada fuente.
SELECT origen, COUNT(*) AS publicaciones FROM tmp_mig004_fechas GROUP BY origen;
DROP TEMPORARY TABLE tmp_mig004_fechas;

-- Toda publicación nueva recibe la fecha automáticamente y nunca queda sin fecha.
ALTER TABLE publicacion
    MODIFY COLUMN fecha_publicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- =========================================================
-- 3. Índice del catálogo: activas, de la más reciente a la más antigua.
-- =========================================================
SET @mig004_falta = NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'publicacion' AND INDEX_NAME = 'idx_publicacion_recientes');
CALL mig004_ddl(@mig004_falta, 'CREATE INDEX idx_publicacion_recientes ON publicacion (activa, fecha_publicacion DESC, id_publicacion DESC)');

-- =========================================================
-- 5 y 6. Procedimientos
-- =========================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_solicitud_publicacion$$
DROP PROCEDURE IF EXISTS sp_aprobar_solicitud_publicacion$$
DROP PROCEDURE IF EXISTS sp_rechazar_solicitud_publicacion$$

-- Publica directamente en el catálogo. La cuenta PENDIENTE puede publicar;
-- RECHAZADA o SUSPENDIDA no. El responsable debe tener "Mi contacto" registrado.
-- fecha_publicacion la asigna MySQL (DEFAULT CURRENT_TIMESTAMP); la auditoría,
-- trg_publicacion_auditar_ai. Un id repetido devuelve ER_DUP_ENTRY: el backend lo
-- usa para que un reintento del mismo envío no cree una segunda publicación.
DROP PROCEDURE IF EXISTS sp_crear_publicacion$$
CREATE PROCEDURE sp_crear_publicacion(
    IN p_id_publicacion VARCHAR(64),
    IN p_id_responsable VARCHAR(64),
    IN p_id_categoria INT UNSIGNED,
    IN p_id_metodo_pago INT UNSIGNED,
    IN p_titulo VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_ubicacion VARCHAR(255),
    IN p_disponible_desde DATE,
    IN p_disponible_hasta DATE,
    IN p_cantidad VARCHAR(100),
    IN p_tipo VARCHAR(20)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(20) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_estado = NULL;  -- responsable inexistente

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF p_tipo IS NULL OR p_tipo NOT IN ('LABOR','SERVICIO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El tipo debe ser LABOR o SERVICIO.';
    END IF;
    IF NULLIF(TRIM(p_titulo),'') IS NULL OR NULLIF(TRIM(p_descripcion),'') IS NULL
       OR NULLIF(TRIM(p_ubicacion),'') IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Título, descripción y ubicación son obligatorios.';
    END IF;
    IF p_disponible_desde IS NULL OR p_disponible_hasta IS NULL
       OR p_disponible_hasta < p_disponible_desde THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La fecha final no puede ser anterior a la inicial.';
    END IF;
    IF p_disponible_hasta < CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La fecha final ya pasó: la publicación no sería visible.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categoria WHERE id_categoria=p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La categoría no existe.';
    END IF;

    START TRANSACTION;

    -- Bloqueo compartido: la Junta no puede suspender la cuenta a mitad de la publicación.
    -- LOCK IN SHARE MODE funciona en MySQL y en MariaDB (FOR SHARE solo en MySQL 8).
    SELECT c.estado INTO v_estado
    FROM cuenta_acceso c
    JOIN contacto_perfil cp ON cp.id_cuenta=c.id_cuenta
    WHERE c.id_cuenta=p_id_responsable
    LOCK IN SHARE MODE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El responsable no existe o no ha registrado Mi contacto.';
    END IF;
    IF v_estado IN ('RECHAZADA','SUSPENDIDA') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La cuenta del responsable no puede publicar. Comunícate con la Junta.';
    END IF;

    SET @actor_app=p_id_responsable;

    INSERT INTO publicacion(
        id_publicacion,id_solicitud_origen,id_categoria,id_responsable,
        id_metodo_pago,titulo,descripcion,ubicacion,disponible_desde,
        disponible_hasta,cantidad,tipo,activa
    ) VALUES (
        p_id_publicacion,NULL,p_id_categoria,p_id_responsable,
        p_id_metodo_pago,TRIM(p_titulo),p_descripcion,TRIM(p_ubicacion),
        p_disponible_desde,p_disponible_hasta,p_cantidad,p_tipo,TRUE
    );

    COMMIT;
    SET @actor_app=NULL;
END$$

DROP PROCEDURE IF EXISTS mig004_ddl$$

DELIMITER ;

-- =========================================================
-- 7. Vista del catálogo (mismas condiciones de vigencia + fecha_publicacion).
-- Una vista no garantiza orden: el backend ordena con
-- ORDER BY fecha_publicacion DESC, id_publicacion DESC.
-- =========================================================
CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_publicaciones_vigentes AS
SELECT
    p.id_publicacion,
    p.titulo,
    p.descripcion,
    p.ubicacion,
    p.disponible_desde,
    p.disponible_hasta,
    p.cantidad,
    p.tipo,
    c.id_categoria,
    c.nombre_categoria,
    p.id_responsable,
    ca.nombre AS responsable,
    p.id_metodo_pago,
    mp.nombre_metodo_pago,
    p.fecha_publicacion
FROM publicacion p
JOIN categoria c ON c.id_categoria=p.id_categoria
JOIN cuenta_acceso ca ON ca.id_cuenta=p.id_responsable
LEFT JOIN metodo_pago mp ON mp.id_metodo_pago=p.id_metodo_pago
WHERE p.activa=TRUE
  AND p.disponible_hasta >= CURRENT_DATE;

-- =========================================================
-- 8. Permisos: solo EXECUTE del nuevo procedimiento (los de los procedimientos
-- retirados desaparecen con DROP PROCEDURE). Sin el rol, no hace nada.
-- (MySQL guarda el rol con Host '%' y MariaDB con Host ''.)
-- =========================================================
SET @mig004_rol = (SELECT COUNT(*) FROM mysql.user WHERE User = 'r_tc_backend' AND Host IN ('%', ''));
SET @mig004_sql = IF(@mig004_rol > 0,
    CONCAT('GRANT EXECUTE ON PROCEDURE `', DATABASE(), '`.sp_crear_publicacion TO ''r_tc_backend'''),
    'DO 0');
PREPARE s FROM @mig004_sql;
EXECUTE s;
DEALLOCATE PREPARE s;

INSERT IGNORE INTO migracion_esquema (version, descripcion)
VALUES ('004', 'Publicación directa sin aprobación: fecha_publicacion, sp_crear_publicacion');

SET SESSION sql_safe_updates = @sh_safe_updates;

-- Verificación
SELECT version, aplicada_en FROM migracion_esquema WHERE version = '004';
SELECT COUNT(*) AS sin_fecha FROM publicacion WHERE fecha_publicacion IS NULL;  -- debe ser 0
-- Solicitudes antiguas conservadas como historial (ya no se aprueban ni se rechazan):
SELECT estado, COUNT(*) AS solicitudes FROM solicitud_publicacion GROUP BY estado;
