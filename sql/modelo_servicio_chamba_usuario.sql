USE servicio_chamba;
CREATE TABLE IF NOT EXISTS cuenta_acceso (
    id_cuenta VARCHAR(64) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    estado ENUM('PENDIENTE','APROBADA','RECHAZADA','SUSPENDIDA')
        NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT pk_cuenta_acceso PRIMARY KEY (id_cuenta)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categoria (
    id_categoria INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre_categoria VARCHAR(120) NOT NULL,
    CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre_categoria)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS metodo_pago (
    id_metodo_pago INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre_metodo_pago VARCHAR(100) NOT NULL,
    CONSTRAINT pk_metodo_pago PRIMARY KEY (id_metodo_pago),
    CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre_metodo_pago)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS solicitud_publicacion (
    id_solicitud VARCHAR(64) NOT NULL,
    id_solicitante VARCHAR(64) NOT NULL,
    id_categoria INT UNSIGNED NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT NOT NULL,
    cantidad VARCHAR(100) NULL,
    ubicacion VARCHAR(255) NOT NULL,
    disponible_desde DATE NOT NULL,
    disponible_hasta DATE NOT NULL,
    contacto_autorizado VARCHAR(255) NOT NULL,
    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('PENDIENTE','APROBADA','RECHAZADA')
        NOT NULL DEFAULT 'PENDIENTE',
    motivo_rechazo TEXT NULL,

    CONSTRAINT pk_solicitud_publicacion PRIMARY KEY (id_solicitud),
    CONSTRAINT fk_sol_pub_solicitante FOREIGN KEY (id_solicitante)
        REFERENCES cuenta_acceso(id_cuenta)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sol_pub_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sol_pub_fechas CHECK (disponible_hasta >= disponible_desde),
    CONSTRAINT ck_sol_pub_rechazo CHECK (
        estado <> 'RECHAZADA' OR motivo_rechazo IS NOT NULL
    )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS publicacion (
    id_publicacion VARCHAR(64) NOT NULL,
    id_solicitud_origen VARCHAR(64) NULL,
    id_categoria INT UNSIGNED NOT NULL,
    id_responsable VARCHAR(64) NOT NULL,
    id_metodo_pago INT UNSIGNED NULL,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT NOT NULL,
    ubicacion VARCHAR(255) NOT NULL,
    disponible_desde DATE NOT NULL,
    disponible_hasta DATE NOT NULL,
    cantidad VARCHAR(100) NULL,
    tipo ENUM('LABOR','SERVICIO') NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_publicacion PRIMARY KEY (id_publicacion),
    CONSTRAINT uq_publicacion_solicitud UNIQUE (id_solicitud_origen),
    CONSTRAINT fk_publicacion_solicitud FOREIGN KEY (id_solicitud_origen)
        REFERENCES solicitud_publicacion(id_solicitud)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_publicacion_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_publicacion_responsable FOREIGN KEY (id_responsable)
        REFERENCES cuenta_acceso(id_cuenta)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_publicacion_metodo_pago FOREIGN KEY (id_metodo_pago)
        REFERENCES metodo_pago(id_metodo_pago)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_publicacion_fechas CHECK (disponible_hasta >= disponible_desde)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS solicitud_contacto (
    id_solicitud_contacto VARCHAR(64) NOT NULL,
    id_publicacion VARCHAR(64) NOT NULL,
    id_remitente VARCHAR(64) NOT NULL,
    id_responsable VARCHAR(64) NOT NULL,
    motivo TEXT NOT NULL,
    telefono_autorizado VARCHAR(30) NOT NULL,
    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('PENDIENTE','APROBADA','RECHAZADA')
        NOT NULL DEFAULT 'PENDIENTE',

    CONSTRAINT pk_solicitud_contacto PRIMARY KEY (id_solicitud_contacto),
    CONSTRAINT fk_contacto_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion(id_publicacion)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_contacto_remitente FOREIGN KEY (id_remitente)
        REFERENCES cuenta_acceso(id_cuenta)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_contacto_responsable FOREIGN KEY (id_responsable)
        REFERENCES cuenta_acceso(id_cuenta)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS historial_gestion (
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor VARCHAR(150) NOT NULL,
    accion VARCHAR(255) NOT NULL,
    elemento_afectado VARCHAR(255) NOT NULL,
    antes LONGTEXT NULL,
    despues LONGTEXT NULL,
    CONSTRAINT ck_historial_antes_json
        CHECK (antes IS NULL OR JSON_VALID(antes)),
    CONSTRAINT ck_historial_despues_json
        CHECK (despues IS NULL OR JSON_VALID(despues))
) ENGINE=InnoDB;

INSERT IGNORE INTO categoria (nombre_categoria) VALUES
('Labores agrícolas'),
('Carpintería'),
('Reparaciones'),
('Otros oficios');


CREATE INDEX idx_cuenta_estado
    ON cuenta_acceso(estado);

CREATE INDEX idx_sol_pub_solicitante_estado_fecha
    ON solicitud_publicacion(id_solicitante,estado,fecha_solicitud);

CREATE INDEX idx_sol_pub_categoria_estado
    ON solicitud_publicacion(id_categoria,estado);

CREATE INDEX idx_publicacion_catalogo
    ON publicacion(activa,disponible_hasta,id_categoria);

CREATE INDEX idx_publicacion_responsable
    ON publicacion(id_responsable);

CREATE INDEX idx_contacto_publicacion_estado_fecha
    ON solicitud_contacto(id_publicacion,estado,fecha_solicitud);

CREATE INDEX idx_contacto_remitente_fecha
    ON solicitud_contacto(id_remitente,fecha_solicitud);

CREATE INDEX idx_contacto_responsable_fecha
    ON solicitud_contacto(id_responsable,fecha_solicitud);

CREATE INDEX idx_historial_elemento_fecha
    ON historial_gestion(elemento_afectado,fecha);
    

DELIMITER $$

DROP TRIGGER IF EXISTS trg_sol_pub_fechas_bi$$
CREATE TRIGGER trg_sol_pub_fechas_bi
BEFORE INSERT ON solicitud_publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La fecha final no puede ser anterior a la inicial.';
    END IF;
END$$
DELIMITER ;
DROP TRIGGER IF EXISTS trg_sol_pub_fechas_bu$$
DELIMITER $$

CREATE TRIGGER trg_sol_pub_fechas_bu
BEFORE UPDATE ON solicitud_publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha final no puede ser anterior a la inicial.';
    END IF;
END$$

DELIMITER ;
DELIMITER $$
DROP TRIGGER IF EXISTS trg_publicacion_fechas_bi$$
CREATE TRIGGER trg_publicacion_fechas_bi
BEFORE INSERT ON publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La fecha final no puede ser anterior a la inicial.';
    END IF;
END$$
DELIMITER ;



DELIMITER $$

DROP TRIGGER IF EXISTS trg_publicacion_fechas_bu$$

CREATE TRIGGER trg_publicacion_fechas_bu
BEFORE UPDATE ON publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha final no puede ser anterior a la inicial.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_contacto_validar_bi$$

CREATE TRIGGER trg_contacto_validar_bi
BEFORE INSERT ON solicitud_contacto
FOR EACH ROW
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_activa BOOLEAN;
    DECLARE v_hasta DATE;
    DECLARE v_responsable VARCHAR(64);

    SELECT COUNT(*), MAX(activa), MAX(disponible_hasta), MAX(id_responsable)
    INTO v_existe, v_activa, v_hasta, v_responsable
    FROM publicacion
    WHERE id_publicacion = NEW.id_publicacion;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La publicación no existe.';
    END IF;

    IF v_activa = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La publicación está cerrada.';
    END IF;

    IF v_hasta < CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La publicación está vencida.';
    END IF;

    IF NEW.id_responsable <> v_responsable THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El responsable no corresponde a la publicación.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_cuenta_auditar_au$$

CREATE TRIGGER trg_cuenta_auditar_au
AFTER UPDATE ON cuenta_acceso
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'ACTUALIZAR_CUENTA',
        CONCAT('cuenta_acceso:', NEW.id_cuenta),
        JSON_OBJECT(
            'id_cuenta', OLD.id_cuenta,
            'nombre', OLD.nombre,
            'estado', OLD.estado
        ),
        JSON_OBJECT(
            'id_cuenta', NEW.id_cuenta,
            'nombre', NEW.nombre,
            'estado', NEW.estado
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_sol_pub_auditar_ai$$

CREATE TRIGGER trg_sol_pub_auditar_ai
AFTER INSERT ON solicitud_publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'CREAR_SOLICITUD_PUBLICACION',
        CONCAT('solicitud_publicacion:', NEW.id_solicitud),
        NULL,
        JSON_OBJECT(
            'id_solicitud', NEW.id_solicitud,
            'id_solicitante', NEW.id_solicitante,
            'id_categoria', NEW.id_categoria,
            'titulo', NEW.titulo,
            'descripcion', NEW.descripcion,
            'cantidad', NEW.cantidad,
            'ubicacion', NEW.ubicacion,
            'disponible_desde', NEW.disponible_desde,
            'disponible_hasta', NEW.disponible_hasta,
            'contacto_autorizado', NEW.contacto_autorizado,
            'fecha_solicitud', NEW.fecha_solicitud,
            'estado', NEW.estado,
            'motivo_rechazo', NEW.motivo_rechazo
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_sol_pub_auditar_au$$

CREATE TRIGGER trg_sol_pub_auditar_au
AFTER UPDATE ON solicitud_publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'ACTUALIZAR_SOLICITUD_PUBLICACION',
        CONCAT('solicitud_publicacion:', NEW.id_solicitud),
        JSON_OBJECT(
            'id_categoria', OLD.id_categoria,
            'titulo', OLD.titulo,
            'descripcion', OLD.descripcion,
            'cantidad', OLD.cantidad,
            'ubicacion', OLD.ubicacion,
            'disponible_desde', OLD.disponible_desde,
            'disponible_hasta', OLD.disponible_hasta,
            'contacto_autorizado', OLD.contacto_autorizado,
            'estado', OLD.estado,
            'motivo_rechazo', OLD.motivo_rechazo
        ),
        JSON_OBJECT(
            'id_categoria', NEW.id_categoria,
            'titulo', NEW.titulo,
            'descripcion', NEW.descripcion,
            'cantidad', NEW.cantidad,
            'ubicacion', NEW.ubicacion,
            'disponible_desde', NEW.disponible_desde,
            'disponible_hasta', NEW.disponible_hasta,
            'contacto_autorizado', NEW.contacto_autorizado,
            'estado', NEW.estado,
            'motivo_rechazo', NEW.motivo_rechazo
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_publicacion_auditar_ai$$

CREATE TRIGGER trg_publicacion_auditar_ai
AFTER INSERT ON publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'CREAR_PUBLICACION',
        CONCAT('publicacion:', NEW.id_publicacion),
        NULL,
        JSON_OBJECT(
            'id_publicacion', NEW.id_publicacion,
            'id_solicitud_origen', NEW.id_solicitud_origen,
            'id_categoria', NEW.id_categoria,
            'id_responsable', NEW.id_responsable,
            'id_metodo_pago', NEW.id_metodo_pago,
            'titulo', NEW.titulo,
            'descripcion', NEW.descripcion,
            'ubicacion', NEW.ubicacion,
            'disponible_desde', NEW.disponible_desde,
            'disponible_hasta', NEW.disponible_hasta,
            'cantidad', NEW.cantidad,
            'tipo', NEW.tipo,
            'activa', NEW.activa
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_publicacion_auditar_au$$

CREATE TRIGGER trg_publicacion_auditar_au
AFTER UPDATE ON publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'ACTUALIZAR_PUBLICACION',
        CONCAT('publicacion:', NEW.id_publicacion),
        JSON_OBJECT(
            'id_categoria', OLD.id_categoria,
            'id_responsable', OLD.id_responsable,
            'id_metodo_pago', OLD.id_metodo_pago,
            'titulo', OLD.titulo,
            'descripcion', OLD.descripcion,
            'ubicacion', OLD.ubicacion,
            'disponible_desde', OLD.disponible_desde,
            'disponible_hasta', OLD.disponible_hasta,
            'cantidad', OLD.cantidad,
            'tipo', OLD.tipo,
            'activa', OLD.activa
        ),
        JSON_OBJECT(
            'id_categoria', NEW.id_categoria,
            'id_responsable', NEW.id_responsable,
            'id_metodo_pago', NEW.id_metodo_pago,
            'titulo', NEW.titulo,
            'descripcion', NEW.descripcion,
            'ubicacion', NEW.ubicacion,
            'disponible_desde', NEW.disponible_desde,
            'disponible_hasta', NEW.disponible_hasta,
            'cantidad', NEW.cantidad,
            'tipo', NEW.tipo,
            'activa', NEW.activa
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_contacto_auditar_ai$$

CREATE TRIGGER trg_contacto_auditar_ai
AFTER INSERT ON solicitud_contacto
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'CREAR_SOLICITUD_CONTACTO',
        CONCAT('solicitud_contacto:', NEW.id_solicitud_contacto),
        NULL,
        JSON_OBJECT(
            'id_solicitud_contacto', NEW.id_solicitud_contacto,
            'id_publicacion', NEW.id_publicacion,
            'id_remitente', NEW.id_remitente,
            'id_responsable', NEW.id_responsable,
            'motivo', NEW.motivo,
            'telefono_autorizado', NEW.telefono_autorizado,
            'fecha_solicitud', NEW.fecha_solicitud,
            'estado', NEW.estado
        )
    );
END$$


DROP TRIGGER IF EXISTS trg_contacto_auditar_au$$

CREATE TRIGGER trg_contacto_auditar_au
AFTER UPDATE ON solicitud_contacto
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion
        (fecha, actor, accion, elemento_afectado, antes, despues)
    VALUES (
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app, ''), CURRENT_USER()),
        'ACTUALIZAR_SOLICITUD_CONTACTO',
        CONCAT('solicitud_contacto:', NEW.id_solicitud_contacto),
        JSON_OBJECT('estado', OLD.estado),
        JSON_OBJECT('estado', NEW.estado)
    );
END$$

DELIMITER ;

-- =========================================================
-- PROCEDIMIENTOS
-- =========================================================
DELIMITER $$
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
DELIMITER ;


DELIMITER $$

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
        SET @actor_app = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo NOT IN ('LABOR', 'SERVICIO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El tipo debe ser LABOR o SERVICIO.';
    END IF;

    START TRANSACTION;
    SET @actor_app = p_actor;

    SELECT estado, id_categoria, titulo, descripcion, cantidad, ubicacion,
           disponible_desde, disponible_hasta
    INTO v_estado, v_categoria, v_titulo, v_descripcion, v_cantidad, v_ubicacion,
         v_desde, v_hasta
    FROM solicitud_publicacion
    WHERE id_solicitud = p_id_solicitud
    FOR UPDATE;

    IF v_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Solo una solicitud PENDIENTE puede aprobarse.';
    END IF;

    UPDATE solicitud_publicacion
    SET estado = 'APROBADA', motivo_rechazo = NULL
    WHERE id_solicitud = p_id_solicitud;

    INSERT INTO publicacion(
        id_publicacion, id_solicitud_origen, id_categoria, id_responsable,
        id_metodo_pago, titulo, descripcion, ubicacion, disponible_desde,
        disponible_hasta, cantidad, tipo, activa
    ) VALUES (
        p_id_publicacion, p_id_solicitud, v_categoria, p_id_responsable,
        p_id_metodo_pago, v_titulo, v_descripcion, v_ubicacion, v_desde, v_hasta,
        v_cantidad, p_tipo, TRUE
    );

    COMMIT;
    SET @actor_app = NULL;
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
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    IF p_motivo_rechazo IS NULL OR TRIM(p_motivo_rechazo) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El motivo del rechazo es obligatorio.';
    END IF;

    SET @actor_app = p_actor;

    UPDATE solicitud_publicacion
    SET estado = 'RECHAZADA', motivo_rechazo = p_motivo_rechazo
    WHERE id_solicitud = p_id_solicitud
      AND estado = 'PENDIENTE';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La solicitud no existe o ya fue procesada.';
    END IF;

    SET @actor_app = NULL;
END$$


DROP PROCEDURE IF EXISTS sp_crear_publicacion_junta$$

CREATE PROCEDURE sp_crear_publicacion_junta(
    IN p_id_publicacion VARCHAR(64),
    IN p_id_categoria INT UNSIGNED,
    IN p_id_responsable VARCHAR(64),
    IN p_id_metodo_pago INT UNSIGNED,
    IN p_titulo VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_ubicacion VARCHAR(255),
    IN p_disponible_desde DATE,
    IN p_disponible_hasta DATE,
    IN p_cantidad VARCHAR(100),
    IN p_tipo VARCHAR(20),
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    IF p_tipo NOT IN ('LABOR', 'SERVICIO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El tipo debe ser LABOR o SERVICIO.';
    END IF;

    SET @actor_app = p_actor;

    INSERT INTO publicacion(
        id_publicacion, id_solicitud_origen, id_categoria, id_responsable,
        id_metodo_pago, titulo, descripcion, ubicacion, disponible_desde,
        disponible_hasta, cantidad, tipo, activa
    ) VALUES (
        p_id_publicacion, NULL, p_id_categoria, p_id_responsable, p_id_metodo_pago,
        p_titulo, p_descripcion, p_ubicacion, p_disponible_desde, p_disponible_hasta,
        p_cantidad, p_tipo, TRUE
    );

    SET @actor_app = NULL;
END$$


DROP PROCEDURE IF EXISTS sp_crear_solicitud_contacto$$

CREATE PROCEDURE sp_crear_solicitud_contacto(
    IN p_id_solicitud_contacto VARCHAR(64),
    IN p_id_publicacion VARCHAR(64),
    IN p_id_remitente VARCHAR(64),
    IN p_motivo TEXT,
    IN p_telefono_autorizado VARCHAR(30)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_responsable VARCHAR(64);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    SELECT id_responsable
    INTO v_responsable
    FROM publicacion
    WHERE id_publicacion = p_id_publicacion;

    SET @actor_app = p_id_remitente;

    INSERT INTO solicitud_contacto(
        id_solicitud_contacto, id_publicacion, id_remitente, id_responsable,
        motivo, telefono_autorizado, fecha_solicitud, estado
    ) VALUES (
        p_id_solicitud_contacto, p_id_publicacion, p_id_remitente, v_responsable,
        p_motivo, p_telefono_autorizado, CURRENT_TIMESTAMP, 'PENDIENTE'
    );

    SET @actor_app = NULL;
END$$


DROP PROCEDURE IF EXISTS sp_actualizar_publicacion$$

CREATE PROCEDURE sp_actualizar_publicacion(
    IN p_id_publicacion VARCHAR(64),
    IN p_descripcion TEXT,
    IN p_cantidad VARCHAR(100),
    IN p_ubicacion VARCHAR(255),
    IN p_disponible_desde DATE,
    IN p_disponible_hasta DATE,
    IN p_id_metodo_pago INT UNSIGNED,
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    SET @actor_app = p_actor;

    UPDATE publicacion
    SET descripcion = p_descripcion,
        cantidad = p_cantidad,
        ubicacion = p_ubicacion,
        disponible_desde = p_disponible_desde,
        disponible_hasta = p_disponible_hasta,
        id_metodo_pago = p_id_metodo_pago
    WHERE id_publicacion = p_id_publicacion;

    SET @actor_app = NULL;
END$$


DROP PROCEDURE IF EXISTS sp_cerrar_publicacion$$

CREATE PROCEDURE sp_cerrar_publicacion(
    IN p_id_publicacion VARCHAR(64),
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    SET @actor_app = p_actor;

    UPDATE publicacion
    SET activa = FALSE
    WHERE id_publicacion = p_id_publicacion
      AND activa = TRUE;

    SET @actor_app = NULL;
END$$


DROP PROCEDURE IF EXISTS sp_cambiar_estado_cuenta$$

CREATE PROCEDURE sp_cambiar_estado_cuenta(
    IN p_id_cuenta VARCHAR(64),
    IN p_nuevo_estado VARCHAR(20),
    IN p_actor VARCHAR(150)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @actor_app = NULL;
        RESIGNAL;
    END;

    IF p_nuevo_estado NOT IN (
        'PENDIENTE', 'APROBADA', 'RECHAZADA', 'SUSPENDIDA'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estado de cuenta no permitido.';
    END IF;

    SET @actor_app = p_actor;

    UPDATE cuenta_acceso
    SET estado = p_nuevo_estado
    WHERE id_cuenta = p_id_cuenta;

    SET @actor_app = NULL;
END$$

DELIMITER ;

DELIMITER $$
-- =========================================================
-- FUNCIÓN / DATO CALCULADO
-- =========================================================

DROP FUNCTION IF EXISTS fn_publicacion_vigente$$
CREATE FUNCTION fn_publicacion_vigente(
    p_activa BOOLEAN,
    p_disponible_hasta DATE
)
RETURNS TINYINT
NOT DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    RETURN (
        p_activa=TRUE
        AND p_disponible_hasta IS NOT NULL
        AND p_disponible_hasta >= CURRENT_DATE
    );
END$$

DELIMITER ;

-- =========================================================
-- VISTAS
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
    mp.nombre_metodo_pago
FROM publicacion p
JOIN categoria c ON c.id_categoria=p.id_categoria
JOIN cuenta_acceso ca ON ca.id_cuenta=p.id_responsable
LEFT JOIN metodo_pago mp ON mp.id_metodo_pago=p.id_metodo_pago
WHERE p.activa=TRUE
  AND p.disponible_hasta >= CURRENT_DATE;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_solicitudes_publicacion AS
SELECT
    sp.id_solicitud,
    sp.id_solicitante,
    ca.nombre AS solicitante,
    sp.id_categoria,
    c.nombre_categoria,
    sp.titulo,
    sp.descripcion,
    sp.cantidad,
    sp.ubicacion,
    sp.disponible_desde,
    sp.disponible_hasta,
    sp.contacto_autorizado,
    sp.fecha_solicitud,
    sp.estado,
    sp.motivo_rechazo
FROM solicitud_publicacion sp
JOIN cuenta_acceso ca ON ca.id_cuenta=sp.id_solicitante
JOIN categoria c ON c.id_categoria=sp.id_categoria;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_solicitudes_contacto AS
SELECT
    sc.id_solicitud_contacto,
    sc.id_publicacion,
    p.titulo AS publicacion,
    sc.id_remitente,
    r.nombre AS remitente,
    sc.id_responsable,
    rs.nombre AS responsable,
    sc.motivo,
    sc.telefono_autorizado,
    sc.fecha_solicitud,
    sc.estado
FROM solicitud_contacto sc
JOIN publicacion p ON p.id_publicacion=sc.id_publicacion
JOIN cuenta_acceso r ON r.id_cuenta=sc.id_remitente
JOIN cuenta_acceso rs ON rs.id_cuenta=sc.id_responsable;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_historial_gestion AS
SELECT fecha,actor,accion,elemento_afectado,antes,despues
FROM historial_gestion;

-- =========================================================
-- USUARIOS, ROLES Y PERMISOS
-- =========================================================

CREATE ROLE IF NOT EXISTS
    'r_tc_admin',
    'r_tc_backend',
    'r_tc_lectura';

GRANT ALL PRIVILEGES
ON servicio_chamba.*
TO 'r_tc_admin';

GRANT SELECT
ON servicio_chamba.*
TO 'r_tc_backend';

GRANT EXECUTE
ON servicio_chamba.*
TO 'r_tc_backend';

GRANT SELECT
ON servicio_chamba.vw_publicaciones_vigentes
TO 'r_tc_lectura';

GRANT SELECT
ON servicio_chamba.categoria
TO 'r_tc_lectura';

GRANT SELECT
ON servicio_chamba.metodo_pago
TO 'r_tc_lectura';