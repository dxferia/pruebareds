-- =========================================================
-- REVERSIÓN DE LA MIGRACIÓN 004 (solo si hay que volver al flujo con aprobación).
-- Restaura los tres procedimientos originales y quita sp_crear_publicacion.
-- Conserva fecha_publicacion, su índice, la vista y los triggers ampliados:
-- son compatibles con el flujo anterior y no se pierden fechas ya registradas.
-- Después hay que desplegar también el backend y la app anteriores.
-- =========================================================
USE sihaychamba;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_publicacion$$

DROP PROCEDURE IF EXISTS sp_crear_solicitud_publicacion$$
CREATE PROCEDURE sp_crear_solicitud_publicacion(
    IN p_id_solicitud VARCHAR(64),
    IN p_id_solicitante VARCHAR(64),
    IN p_id_categoria INT UNSIGNED,
    IN p_titulo VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_cantidad VARCHAR(100),
    IN p_ubicacion VARCHAR(255),
    IN p_disponible_desde DATE,
    IN p_disponible_hasta DATE,
    IN p_contacto_autorizado VARCHAR(255)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    SET @actor_app=p_id_solicitante;

    INSERT INTO solicitud_publicacion(
        id_solicitud,id_solicitante,id_categoria,titulo,descripcion,cantidad,
        ubicacion,disponible_desde,disponible_hasta,contacto_autorizado,
        fecha_solicitud,estado,motivo_rechazo
    ) VALUES (
        p_id_solicitud,p_id_solicitante,p_id_categoria,p_titulo,p_descripcion,
        p_cantidad,p_ubicacion,p_disponible_desde,p_disponible_hasta,
        p_contacto_autorizado,CURRENT_TIMESTAMP,'PENDIENTE',NULL
    );

    SET @actor_app=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_aprobar_solicitud_publicacion$$
CREATE PROCEDURE sp_aprobar_solicitud_publicacion(
    IN p_id_solicitud VARCHAR(64),
    IN p_id_publicacion VARCHAR(64),
    IN p_id_responsable VARCHAR(64),
    IN p_id_metodo_pago INT UNSIGNED,
    IN p_tipo VARCHAR(20),
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_categoria INT UNSIGNED;
    DECLARE v_titulo VARCHAR(255);
    DECLARE v_descripcion TEXT;
    DECLARE v_cantidad VARCHAR(100);
    DECLARE v_ubicacion VARCHAR(255);
    DECLARE v_desde DATE;
    DECLARE v_hasta DATE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app=NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo NOT IN ('LABOR','SERVICIO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='El tipo debe ser LABOR o SERVICIO.';
    END IF;

    START TRANSACTION;
    SET @actor_app=p_actor;

    SELECT estado,id_categoria,titulo,descripcion,cantidad,ubicacion,
           disponible_desde,disponible_hasta
    INTO v_estado,v_categoria,v_titulo,v_descripcion,v_cantidad,v_ubicacion,
         v_desde,v_hasta
    FROM solicitud_publicacion
    WHERE id_solicitud=p_id_solicitud
    FOR UPDATE;

    IF v_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='Solo una solicitud PENDIENTE puede aprobarse.';
    END IF;

    UPDATE solicitud_publicacion
    SET estado='APROBADA', motivo_rechazo=NULL
    WHERE id_solicitud=p_id_solicitud;

    INSERT INTO publicacion(
        id_publicacion,id_solicitud_origen,id_categoria,id_responsable,
        id_metodo_pago,titulo,descripcion,ubicacion,disponible_desde,
        disponible_hasta,cantidad,tipo,activa
    ) VALUES (
        p_id_publicacion,p_id_solicitud,v_categoria,p_id_responsable,
        p_id_metodo_pago,v_titulo,v_descripcion,v_ubicacion,v_desde,v_hasta,
        v_cantidad,p_tipo,TRUE
    );

    COMMIT;
    SET @actor_app=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_rechazar_solicitud_publicacion$$
CREATE PROCEDURE sp_rechazar_solicitud_publicacion(
    IN p_id_solicitud VARCHAR(64),
    IN p_motivo_rechazo TEXT,
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF p_motivo_rechazo IS NULL OR TRIM(p_motivo_rechazo)='' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='El motivo del rechazo es obligatorio.';
    END IF;

    SET @actor_app=p_actor;

    UPDATE solicitud_publicacion
    SET estado='RECHAZADA', motivo_rechazo=p_motivo_rechazo
    WHERE id_solicitud=p_id_solicitud AND estado='PENDIENTE';

    IF ROW_COUNT()=0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La solicitud no existe o ya fue procesada.';
    END IF;

    SET @actor_app=NULL;
END$$

DELIMITER ;

DELETE FROM migracion_esquema WHERE version = '004';
