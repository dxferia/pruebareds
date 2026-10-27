-- =========================================================
-- SIHAYCHAMBA · SCRIPT COMPLETO (base + Mi contacto/encuestas + publicación directa)
--
-- Funciona en MySQL 8.0+ y en MariaDB 10.6+. Sirve para dos situaciones, como root en 127.0.0.1:3308:
--   · Base nueva: crea todo desde cero.
--   · Base existente: la actualiza SIN borrar datos (re-ejecutable).
--     Antes, respáldala:
--     mysqldump -h 127.0.0.1 -P 3308 -u root -p --routines --triggers sihaychamba > respaldo.sql
--
-- Cambios respecto al script anterior:
--   · publicacion.fecha_publicacion (DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP) e
--     índice idx_publicacion_recientes; fechas anteriores recuperadas del historial.
--   · sp_crear_publicacion reemplaza a sp_crear_solicitud_publicacion,
--     sp_aprobar_solicitud_publicacion y sp_rechazar_solicitud_publicacion: lo que se
--     publica aparece al instante, sin aprobación de la Junta.
--   · vw_publicaciones_vigentes y la auditoría de publicacion incluyen fecha_publicacion.
--   · solicitud_publicacion y vw_solicitudes_publicacion se conservan como historial.
--   · Los índices ya no fallan al volver a ejecutar el script.
--   · Se quitaron las consultas de depuración (SHOW, SELECT *) y el DROP ROLE final,
--     que eliminaba los roles recién creados.
-- =========================================================

-- SIHAYCHAMBA (TRAVESÍAS CONECTA) - MODELO FÍSICO MYSQL 8.0+ / MARIADB 10.6+
-- 7 entidades: cuenta_acceso, categoria, solicitud_publicacion, publicacion,
-- metodo_pago, solicitud_contacto, historial_gestion.
-- No incluye pagos/transacciones ni contratos.
-- En MySQL, SCHEMA es sinónimo de DATABASE. No se usan SYNONYMS ni SEQUENCES.

CREATE DATABASE IF NOT EXISTS sihaychamba
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE sihaychamba;
SET NAMES utf8mb4;

-- Workbench usa «safe update mode» (error 1175 en el UPDATE ... JOIN de fechas).
-- Se desactiva solo en esta sesión y al final se restaura el valor que tenías.
SET @sh_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;

-- =========================================================
-- TABLAS
-- =========================================================

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
    fecha_publicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

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

-- =========================================================
-- ACTUALIZACIÓN DE UNA BASE EXISTENTE (versión 004: publicación directa)
-- En una base nueva no cambia nada. En una base anterior: respalda publicacion en
-- respaldo_004_publicacion, agrega fecha_publicacion y recupera la fecha real del historial.
-- =========================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sh_agregar_fecha_publicacion$$
CREATE PROCEDURE sh_agregar_fecha_publicacion()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'publicacion'
                     AND COLUMN_NAME = 'fecha_publicacion') THEN
        CREATE TABLE IF NOT EXISTS respaldo_004_publicacion AS SELECT * FROM publicacion;
        ALTER TABLE publicacion ADD COLUMN fecha_publicacion DATETIME NULL AFTER activa;
    END IF;
END$$

-- CREATE INDEX solo si no existe: el script se puede volver a ejecutar.
DROP PROCEDURE IF EXISTS sh_crear_indice$$
CREATE PROCEDURE sh_crear_indice(IN p_tabla VARCHAR(64), IN p_indice VARCHAR(64), IN p_columnas VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_tabla AND INDEX_NAME = p_indice) THEN
        SET @sh_sql = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_tabla, ' (', p_columnas, ')');
        PREPARE s FROM @sh_sql;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;
END$$

DELIMITER ;

CALL sh_agregar_fecha_publicacion();
-- =========================================================
-- REGISTROS INICIALES
-- =========================================================

INSERT IGNORE INTO categoria (nombre_categoria) VALUES
('Labores agrícolas'),
('Carpintería'),
('Reparaciones'),
('Otros oficios');

INSERT IGNORE INTO cuenta_acceso (id_cuenta,nombre,estado) VALUES
('acc-001','María P.','PENDIENTE'),
('acc-002','Carlos R.','APROBADA'),
('acc-003','Luis G.','SUSPENDIDA');

-- No se insertan métodos de pago porque el proyecto aún no define
-- nombres concretos para ellos.
-- No se insertan publicaciones ni solicitudes ficticias para no inventar FK.

-- =========================================================
-- ÍNDICES
-- =========================================================

CALL sh_crear_indice('cuenta_acceso', 'idx_cuenta_estado', 'estado');

CALL sh_crear_indice('solicitud_publicacion', 'idx_sol_pub_solicitante_estado_fecha', 'id_solicitante,estado,fecha_solicitud');

CALL sh_crear_indice('solicitud_publicacion', 'idx_sol_pub_categoria_estado', 'id_categoria,estado');

CALL sh_crear_indice('publicacion', 'idx_publicacion_catalogo', 'activa,disponible_hasta,id_categoria');

CALL sh_crear_indice('publicacion', 'idx_publicacion_responsable', 'id_responsable');

CALL sh_crear_indice('solicitud_contacto', 'idx_contacto_publicacion_estado_fecha', 'id_publicacion,estado,fecha_solicitud');

CALL sh_crear_indice('solicitud_contacto', 'idx_contacto_remitente_fecha', 'id_remitente,fecha_solicitud');

CALL sh_crear_indice('solicitud_contacto', 'idx_contacto_responsable_fecha', 'id_responsable,fecha_solicitud');

CALL sh_crear_indice('historial_gestion', 'idx_historial_elemento_fecha', 'elemento_afectado,fecha');

-- Catálogo: activas, de la más reciente a la más antigua.
CALL sh_crear_indice('publicacion', 'idx_publicacion_recientes', 'activa, fecha_publicacion DESC, id_publicacion DESC');

-- =========================================================
-- TRIGGERS
-- =========================================================

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

DROP TRIGGER IF EXISTS trg_sol_pub_fechas_bu$$
CREATE TRIGGER trg_sol_pub_fechas_bu
BEFORE UPDATE ON solicitud_publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La fecha final no puede ser anterior a la inicial.';
    END IF;
END$$

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

DROP TRIGGER IF EXISTS trg_publicacion_fechas_bu$$
CREATE TRIGGER trg_publicacion_fechas_bu
BEFORE UPDATE ON publicacion
FOR EACH ROW
BEGIN
    IF NEW.disponible_hasta < NEW.disponible_desde THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La fecha final no puede ser anterior a la inicial.';
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
        SET MESSAGE_TEXT='La publicación no existe.';
    END IF;

    IF v_activa = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La publicación está cerrada.';
    END IF;

    IF v_hasta < CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='La publicación está vencida.';
    END IF;

    IF NEW.id_responsable <> v_responsable THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='El responsable no corresponde a la publicación.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_cuenta_auditar_au$$
CREATE TRIGGER trg_cuenta_auditar_au
AFTER UPDATE ON cuenta_acceso
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_CUENTA',
        CONCAT('cuenta_acceso:',NEW.id_cuenta),
        JSON_OBJECT('id_cuenta',OLD.id_cuenta,'nombre',OLD.nombre,'estado',OLD.estado),
        JSON_OBJECT('id_cuenta',NEW.id_cuenta,'nombre',NEW.nombre,'estado',NEW.estado)
    );
END$$

DROP TRIGGER IF EXISTS trg_sol_pub_auditar_ai$$
CREATE TRIGGER trg_sol_pub_auditar_ai
AFTER INSERT ON solicitud_publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'CREAR_SOLICITUD_PUBLICACION',
        CONCAT('solicitud_publicacion:',NEW.id_solicitud),
        NULL,
        JSON_OBJECT(
            'id_solicitud',NEW.id_solicitud,
            'id_solicitante',NEW.id_solicitante,
            'id_categoria',NEW.id_categoria,
            'titulo',NEW.titulo,
            'descripcion',NEW.descripcion,
            'cantidad',NEW.cantidad,
            'ubicacion',NEW.ubicacion,
            'disponible_desde',NEW.disponible_desde,
            'disponible_hasta',NEW.disponible_hasta,
            'contacto_autorizado',NEW.contacto_autorizado,
            'fecha_solicitud',NEW.fecha_solicitud,
            'estado',NEW.estado,
            'motivo_rechazo',NEW.motivo_rechazo
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_sol_pub_auditar_au$$
CREATE TRIGGER trg_sol_pub_auditar_au
AFTER UPDATE ON solicitud_publicacion
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_SOLICITUD_PUBLICACION',
        CONCAT('solicitud_publicacion:',NEW.id_solicitud),
        JSON_OBJECT(
            'id_categoria',OLD.id_categoria,'titulo',OLD.titulo,
            'descripcion',OLD.descripcion,'cantidad',OLD.cantidad,
            'ubicacion',OLD.ubicacion,'disponible_desde',OLD.disponible_desde,
            'disponible_hasta',OLD.disponible_hasta,
            'contacto_autorizado',OLD.contacto_autorizado,
            'estado',OLD.estado,'motivo_rechazo',OLD.motivo_rechazo
        ),
        JSON_OBJECT(
            'id_categoria',NEW.id_categoria,'titulo',NEW.titulo,
            'descripcion',NEW.descripcion,'cantidad',NEW.cantidad,
            'ubicacion',NEW.ubicacion,'disponible_desde',NEW.disponible_desde,
            'disponible_hasta',NEW.disponible_hasta,
            'contacto_autorizado',NEW.contacto_autorizado,
            'estado',NEW.estado,'motivo_rechazo',NEW.motivo_rechazo
        )
    );
END$$

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

DROP TRIGGER IF EXISTS trg_contacto_auditar_ai$$
CREATE TRIGGER trg_contacto_auditar_ai
AFTER INSERT ON solicitud_contacto
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'CREAR_SOLICITUD_CONTACTO',
        CONCAT('solicitud_contacto:',NEW.id_solicitud_contacto),
        NULL,
        JSON_OBJECT(
            'id_solicitud_contacto',NEW.id_solicitud_contacto,
            'id_publicacion',NEW.id_publicacion,
            'id_remitente',NEW.id_remitente,
            'id_responsable',NEW.id_responsable,
            'motivo',NEW.motivo,
            'telefono_autorizado',NEW.telefono_autorizado,
            'fecha_solicitud',NEW.fecha_solicitud,
            'estado',NEW.estado
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_contacto_auditar_au$$
CREATE TRIGGER trg_contacto_auditar_au
AFTER UPDATE ON solicitud_contacto
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_SOLICITUD_CONTACTO',
        CONCAT('solicitud_contacto:',NEW.id_solicitud_contacto),
        JSON_OBJECT('estado',OLD.estado),
        JSON_OBJECT('estado',NEW.estado)
    );
END$$

-- =========================================================
-- PROCEDIMIENTOS
-- =========================================================

-- Flujo de aprobación retirado (versión 004): las publicaciones se crean directo
-- con sp_crear_publicacion. Se conservan solicitud_publicacion y su historial.
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
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF p_tipo NOT IN ('LABOR','SERVICIO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='El tipo debe ser LABOR o SERVICIO.';
    END IF;

    SET @actor_app=p_actor;

    INSERT INTO publicacion(
        id_publicacion,id_solicitud_origen,id_categoria,id_responsable,
        id_metodo_pago,titulo,descripcion,ubicacion,disponible_desde,
        disponible_hasta,cantidad,tipo,activa
    ) VALUES (
        p_id_publicacion,NULL,p_id_categoria,p_id_responsable,p_id_metodo_pago,
        p_titulo,p_descripcion,p_ubicacion,p_disponible_desde,p_disponible_hasta,
        p_cantidad,p_tipo,TRUE
    );

    SET @actor_app=NULL;
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
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    SELECT id_responsable
    INTO v_responsable
    FROM publicacion
    WHERE id_publicacion=p_id_publicacion;

    SET @actor_app=p_id_remitente;

    INSERT INTO solicitud_contacto(
        id_solicitud_contacto,id_publicacion,id_remitente,id_responsable,
        motivo,telefono_autorizado,fecha_solicitud,estado
    ) VALUES (
        p_id_solicitud_contacto,p_id_publicacion,p_id_remitente,v_responsable,
        p_motivo,p_telefono_autorizado,CURRENT_TIMESTAMP,'PENDIENTE'
    );

    SET @actor_app=NULL;
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
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    SET @actor_app=p_actor;

    UPDATE publicacion
    SET descripcion=p_descripcion,
        cantidad=p_cantidad,
        ubicacion=p_ubicacion,
        disponible_desde=p_disponible_desde,
        disponible_hasta=p_disponible_hasta,
        id_metodo_pago=p_id_metodo_pago
    WHERE id_publicacion=p_id_publicacion;

    SET @actor_app=NULL;
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
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    SET @actor_app=p_actor;

    UPDATE publicacion
    SET activa=FALSE
    WHERE id_publicacion=p_id_publicacion AND activa=TRUE;

    SET @actor_app=NULL;
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
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF p_nuevo_estado NOT IN ('PENDIENTE','APROBADA','RECHAZADA','SUSPENDIDA') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='Estado de cuenta no permitido.';
    END IF;

    SET @actor_app=p_actor;

    UPDATE cuenta_acceso
    SET estado=p_nuevo_estado
    WHERE id_cuenta=p_id_cuenta;

    SET @actor_app=NULL;
END$$

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
-- FECHAS DE PUBLICACIONES ANTERIORES (solo en una base existente)
-- (a) historial CREAR_PUBLICACION; (b) aprobación de su solicitud de origen;
-- (c) respaldo documentado 2000-01-01 00:00:00 (sin rastro histórico).
-- =========================================================

DROP TEMPORARY TABLE IF EXISTS tmp_sh_fechas;
CREATE TEMPORARY TABLE tmp_sh_fechas (
    id_publicacion VARCHAR(64) NOT NULL PRIMARY KEY,
    fecha DATETIME NOT NULL,
    origen VARCHAR(40) NOT NULL
);

INSERT INTO tmp_sh_fechas (id_publicacion, fecha, origen)
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

SET @actor_app = 'actualizacion_004';
UPDATE publicacion p
JOIN tmp_sh_fechas t ON t.id_publicacion = p.id_publicacion
SET p.fecha_publicacion = t.fecha;
SET @actor_app = NULL;

-- Informe: cuántas fechas salieron de cada fuente.
SELECT origen, COUNT(*) AS publicaciones FROM tmp_sh_fechas GROUP BY origen;
DROP TEMPORARY TABLE tmp_sh_fechas;

-- Toda publicación nueva recibe la fecha automáticamente y nunca queda sin fecha.
ALTER TABLE publicacion
    MODIFY COLUMN fecha_publicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- =========================================================
-- VISTAS
-- =========================================================

-- No garantiza orden: el backend usa ORDER BY fecha_publicacion DESC, id_publicacion DESC.
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
-- SINÓNIMOS: OMITIDO
-- MySQL no tiene CREATE SYNONYM general al estilo Oracle.
-- =========================================================

-- =========================================================
-- SECUENCIAS: OMITIDO
-- categoria y metodo_pago usan AUTO_INCREMENT.
-- IDs funcionales siguen siendo VARCHAR(64).
-- =========================================================

-- =========================================================
-- AUDITORÍA
-- historial_gestion + triggers guardan ANTES y DESPUÉS.
-- =========================================================

-- =========================================================
-- USUARIOS, ROLES Y PERMISOS
-- =========================================================

-- Un rol por sentencia: MariaDB no admite varios en el mismo CREATE ROLE.
CREATE ROLE IF NOT EXISTS 'r_tc_admin';
CREATE ROLE IF NOT EXISTS 'r_tc_backend';
CREATE ROLE IF NOT EXISTS 'r_tc_lectura';

GRANT ALL PRIVILEGES
ON sihaychamba.*
TO 'r_tc_admin';

GRANT SELECT
ON sihaychamba.*
TO 'r_tc_backend';

GRANT EXECUTE
ON sihaychamba.*
TO 'r_tc_backend';

GRANT SELECT
ON sihaychamba.vw_publicaciones_vigentes
TO 'r_tc_lectura';

GRANT SELECT
ON sihaychamba.categoria
TO 'r_tc_lectura';

GRANT SELECT
ON sihaychamba.metodo_pago
TO 'r_tc_lectura';

-- Usuarios locales de desarrollo. Cambiar contraseñas antes de desplegar.
CREATE USER IF NOT EXISTS 'tc_admin'@'localhost'
IDENTIFIED BY 'TcAdmin#Cambiar2026!';

CREATE USER IF NOT EXISTS 'tc_backend'@'localhost'
IDENTIFIED BY 'TcBackend#Cambiar2026!';

CREATE USER IF NOT EXISTS 'tc_lectura'@'localhost'
IDENTIFIED BY 'TcLectura#Cambiar2026!';

GRANT 'r_tc_admin' TO 'tc_admin'@'localhost';
GRANT 'r_tc_backend' TO 'tc_backend'@'localhost';
GRANT 'r_tc_lectura' TO 'tc_lectura'@'localhost';

-- Rol por defecto: MySQL usa «SET DEFAULT ROLE r TO u» y MariaDB «SET DEFAULT ROLE r FOR u».
DELIMITER $$
DROP PROCEDURE IF EXISTS sh_rol_por_defecto$$
CREATE PROCEDURE sh_rol_por_defecto(IN p_rol VARCHAR(64), IN p_usuario VARCHAR(64))
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        SELECT CONCAT('Aviso: asigna a mano el rol ', p_rol, ' por defecto a ', p_usuario) AS aviso;
    SET @sh_sql = IF(VERSION() LIKE '%MariaDB%',
        CONCAT('SET DEFAULT ROLE ', p_rol, ' FOR ', p_usuario, '@localhost'),
        CONCAT('SET DEFAULT ROLE ', p_rol, ' TO ', p_usuario, '@localhost'));
    PREPARE s FROM @sh_sql;
    EXECUTE s;
    DEALLOCATE PREPARE s;
END$$
DELIMITER ;

CALL sh_rol_por_defecto('r_tc_admin', 'tc_admin');
CALL sh_rol_por_defecto('r_tc_backend', 'tc_backend');
CALL sh_rol_por_defecto('r_tc_lectura', 'tc_lectura');
DROP PROCEDURE IF EXISTS sh_rol_por_defecto;

-- CARDINALIDADES:
-- cuenta_acceso         1:N solicitud_publicacion
-- categoria             1:N solicitud_publicacion
-- solicitud_publicacion 1:0..1 publicacion
-- cuenta_acceso         1:N publicacion (responsable)
-- categoria             1:N publicacion
-- metodo_pago           1:N publicacion
-- publicacion           1:N solicitud_contacto
-- cuenta_acceso         1:N solicitud_contacto (remitente)
-- cuenta_acceso         1:N solicitud_contacto (responsable)

-- =========================================================
-- EXTENSIÓN DE sihaychamba: MI CONTACTO Y ENCUESTAS
-- Ejecutar en MySQL Workbench DESPUÉS de bd_sihaychamba.sql
-- (requiere cuenta_acceso e historial_gestion). Reemplaza a 001/002.
-- Es re-ejecutable: no borra tablas ni datos.
--
--   Tablas: contacto_perfil, encuesta, pregunta_encuesta,
--           respuesta_encuesta, detalle_respuesta_encuesta
--   d. REGISTROS ............ encuesta de usabilidad + 5 preguntas
--   e. TRIGGERS ............. validación, inmutabilidad y auditoría
--   f. PROCEDIMIENTOS ....... contacto, respuestas, estado de encuesta
--   g. FUNCIONES ............ fn_encuesta_vigente, fn_valor_escala
--   h. SINÓNIMOS ............ no existen en MySQL (ver nota)
--   i. VISTAS ............... contactos, encuestas vigentes, resultados, auditoría
--   j. ÍNDICES .............. declarados dentro de cada CREATE TABLE
--   k. SECUENCIAS ........... AUTO_INCREMENT (ver nota)
--   l. DATOS CALCULADOS ..... totales, promedio, % favorable, vigencia
--   m. AUDITORÍAS ........... triggers → historial_gestion
-- =========================================================
USE sihaychamba;

-- =========================================================
-- TABLAS  (j. ÍNDICES incluidos en cada definición)
-- =========================================================

CREATE TABLE IF NOT EXISTS contacto_perfil (
    id_cuenta VARCHAR(64) NOT NULL,
    correo VARCHAR(254) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    medio_preferido ENUM('LLAMADA','WHATSAPP','CORREO') NOT NULL DEFAULT 'WHATSAPP',
    clave_edicion_hash CHAR(64) NOT NULL,          -- SHA-256 de la X-Contact-Key; la clave real nunca se guarda
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_contacto_perfil PRIMARY KEY (id_cuenta),
    CONSTRAINT uq_contacto_clave_hash UNIQUE (clave_edicion_hash),
    CONSTRAINT fk_contacto_cuenta FOREIGN KEY (id_cuenta)
        REFERENCES cuenta_acceso(id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_contacto_correo CHECK (correo LIKE '%_@_%._%'),
    CONSTRAINT ck_contacto_telefono CHECK (CHAR_LENGTH(telefono) BETWEEN 7 AND 30),
    CONSTRAINT ck_contacto_hash CHECK (CHAR_LENGTH(clave_edicion_hash) = 64),
    INDEX idx_contacto_correo (correo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS encuesta (
    id_encuesta VARCHAR(64) NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT NOT NULL,
    version_encuesta SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    estado ENUM('BORRADOR','ACTIVA','CERRADA') NOT NULL DEFAULT 'BORRADOR',
    disponible_desde DATETIME NULL,
    disponible_hasta DATETIME NULL,
    CONSTRAINT pk_encuesta PRIMARY KEY (id_encuesta),
    CONSTRAINT ck_encuesta_periodo CHECK (
        disponible_hasta IS NULL OR disponible_desde IS NULL OR disponible_hasta >= disponible_desde),
    INDEX idx_encuesta_vigencia (estado, disponible_desde, disponible_hasta)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pregunta_encuesta (
    id_pregunta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_encuesta VARCHAR(64) NOT NULL,
    numero SMALLINT UNSIGNED NOT NULL,
    texto TEXT NOT NULL,
    tipo ENUM('ESCALA','TEXTO','UNICA','MULTIPLE') NOT NULL,
    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
    opciones_json JSON NULL,                       -- lista de opciones para UNICA / MULTIPLE
    CONSTRAINT pk_pregunta_encuesta PRIMARY KEY (id_pregunta),
    CONSTRAINT uq_pregunta_orden UNIQUE (id_encuesta, numero),
    CONSTRAINT fk_pregunta_encuesta FOREIGN KEY (id_encuesta)
        REFERENCES encuesta(id_encuesta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pregunta_numero CHECK (numero > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS respuesta_encuesta (
    id_respuesta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_encuesta VARCHAR(64) NOT NULL,
    id_contacto VARCHAR(64) NULL,                  -- NULL = respuesta anónima
    fecha_envio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_respuesta_encuesta PRIMARY KEY (id_respuesta),
    -- Una respuesta por contacto y encuesta (los NULL anónimos no colisionan).
    CONSTRAINT uq_encuesta_contacto UNIQUE (id_encuesta, id_contacto),
    CONSTRAINT fk_respuesta_encuesta FOREIGN KEY (id_encuesta)
        REFERENCES encuesta(id_encuesta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_respuesta_contacto FOREIGN KEY (id_contacto)
        REFERENCES cuenta_acceso(id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_respuesta_fecha (id_encuesta, fecha_envio)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_respuesta_encuesta (
    id_detalle BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_respuesta BIGINT UNSIGNED NOT NULL,
    id_pregunta BIGINT UNSIGNED NOT NULL,
    valor_json JSON NOT NULL,                      -- 4 | "texto" | "opción" | ["a","b"]
    CONSTRAINT pk_detalle_respuesta PRIMARY KEY (id_detalle),
    CONSTRAINT uq_detalle_pregunta UNIQUE (id_respuesta, id_pregunta),
    CONSTRAINT fk_detalle_respuesta FOREIGN KEY (id_respuesta)
        REFERENCES respuesta_encuesta(id_respuesta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_pregunta FOREIGN KEY (id_pregunta)
        REFERENCES pregunta_encuesta(id_pregunta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_detalle_pregunta (id_pregunta)        -- acelera vw_resultados_encuesta
) ENGINE=InnoDB;

DELIMITER $$

-- =========================================================
-- g. FUNCIONES  (l. datos calculados)
-- =========================================================

-- 1 si la encuesta está ACTIVA y dentro de su periodo; 0 en otro caso.
DROP FUNCTION IF EXISTS fn_encuesta_vigente$$
CREATE FUNCTION fn_encuesta_vigente(
    p_estado VARCHAR(20),
    p_desde DATETIME,
    p_hasta DATETIME
)
RETURNS TINYINT
NOT DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    RETURN (
        p_estado = 'ACTIVA'
        AND (p_desde IS NULL OR p_desde <= NOW())
        AND (p_hasta IS NULL OR p_hasta >= NOW())
    );
END$$

-- Valor numérico 1..5 de una respuesta tipo ESCALA; NULL si no es un entero válido.
DROP FUNCTION IF EXISTS fn_valor_escala$$
CREATE FUNCTION fn_valor_escala(p_valor JSON)
RETURNS TINYINT
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    IF JSON_TYPE(p_valor) IN ('INTEGER','UNSIGNED INTEGER')
       AND CAST(p_valor AS SIGNED) BETWEEN 1 AND 5 THEN
        RETURN CAST(p_valor AS SIGNED);
    END IF;
    RETURN NULL;
END$$

-- =========================================================
-- f. PROCEDIMIENTOS ALMACENADOS
-- =========================================================

-- Valida la coherencia tipo/opciones de una pregunta (lo usan los triggers de pregunta_encuesta).
DROP PROCEDURE IF EXISTS sp_validar_pregunta$$
CREATE PROCEDURE sp_validar_pregunta(IN p_tipo VARCHAR(10), IN p_opciones JSON)
NO SQL
SQL SECURITY INVOKER
BEGIN
    IF p_tipo IN ('UNICA','MULTIPLE') AND (p_opciones IS NULL
       OR JSON_TYPE(p_opciones) <> 'ARRAY' OR JSON_LENGTH(p_opciones) < 2) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='Las preguntas UNICA y MULTIPLE requieren al menos dos opciones.';
    END IF;
    IF p_tipo IN ('ESCALA','TEXTO') AND p_opciones IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT='Las preguntas ESCALA y TEXTO no llevan opciones.';
    END IF;
END$$

-- Registra "Mi contacto": cuenta PENDIENTE (la valida la Junta) + perfil, en una sola transacción.
DROP PROCEDURE IF EXISTS sp_crear_contacto$$
CREATE PROCEDURE sp_crear_contacto(
    IN p_id_cuenta VARCHAR(64),
    IN p_nombre VARCHAR(150),
    IN p_correo VARCHAR(254),
    IN p_telefono VARCHAR(30),
    IN p_medio VARCHAR(20),
    IN p_clave_hash CHAR(64)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @actor_app=p_id_cuenta;

    INSERT INTO cuenta_acceso(id_cuenta,nombre,estado)
    VALUES(p_id_cuenta,p_nombre,'PENDIENTE');

    INSERT INTO contacto_perfil(id_cuenta,correo,telefono,medio_preferido,clave_edicion_hash)
    VALUES(p_id_cuenta,p_correo,p_telefono,p_medio,p_clave_hash);

    COMMIT;
    SET @actor_app=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_actualizar_contacto$$
CREATE PROCEDURE sp_actualizar_contacto(
    IN p_id_cuenta VARCHAR(64),
    IN p_nombre VARCHAR(150),
    IN p_correo VARCHAR(254),
    IN p_telefono VARCHAR(30),
    IN p_medio VARCHAR(20)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM contacto_perfil WHERE id_cuenta=p_id_cuenta) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El contacto no existe.';
    END IF;

    START TRANSACTION;
    SET @actor_app=p_id_cuenta;

    UPDATE cuenta_acceso SET nombre=p_nombre WHERE id_cuenta=p_id_cuenta;
    UPDATE contacto_perfil
    SET correo=p_correo, telefono=p_telefono, medio_preferido=p_medio
    WHERE id_cuenta=p_id_cuenta;

    COMMIT;
    SET @actor_app=NULL;
END$$

-- Guarda una respuesta completa. p_respuestas: [{"id_pregunta":1,"valor":4}, ...]
-- Devuelve un result set con id_respuesta.
DROP PROCEDURE IF EXISTS sp_registrar_respuesta_encuesta$$
CREATE PROCEDURE sp_registrar_respuesta_encuesta(
    IN p_id_encuesta VARCHAR(64),
    IN p_id_contacto VARCHAR(64),
    IN p_respuestas JSON
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_id BIGINT UNSIGNED;
    DECLARE v_faltan INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @actor_app=NULL;
        RESIGNAL;
    END;

    IF p_respuestas IS NULL OR JSON_TYPE(p_respuestas) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las respuestas deben enviarse como una lista.';
    END IF;

    SELECT COUNT(*) INTO v_faltan
    FROM pregunta_encuesta p
    WHERE p.id_encuesta=p_id_encuesta AND p.obligatoria
      AND p.id_pregunta NOT IN (
          SELECT j.id_pregunta
          FROM JSON_TABLE(p_respuestas,'$[*]'
               COLUMNS(id_pregunta BIGINT UNSIGNED PATH '$.id_pregunta')) j
          WHERE j.id_pregunta IS NOT NULL);

    IF v_faltan > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan respuestas obligatorias.';
    END IF;

    START TRANSACTION;
    SET @actor_app=COALESCE(p_id_contacto,'anonimo');

    INSERT INTO respuesta_encuesta(id_encuesta,id_contacto)
    VALUES(p_id_encuesta,p_id_contacto);
    SET v_id=LAST_INSERT_ID();

    -- Cada detalle pasa por trg_detalle_validar_bi.
    INSERT INTO detalle_respuesta_encuesta(id_respuesta,id_pregunta,valor_json)
    SELECT v_id, j.id_pregunta, j.valor
    FROM JSON_TABLE(p_respuestas,'$[*]'
         COLUMNS(id_pregunta BIGINT UNSIGNED PATH '$.id_pregunta',
                 valor JSON PATH '$.valor')) j;

    COMMIT;
    SET @actor_app=NULL;
    SELECT v_id AS id_respuesta;
END$$

DROP PROCEDURE IF EXISTS sp_cambiar_estado_encuesta$$
CREATE PROCEDURE sp_cambiar_estado_encuesta(
    IN p_id_encuesta VARCHAR(64),
    IN p_estado VARCHAR(20),
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

    IF p_estado NOT IN ('BORRADOR','ACTIVA','CERRADA') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Estado de encuesta no permitido.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM encuesta WHERE id_encuesta=p_id_encuesta) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La encuesta no existe.';
    END IF;

    SET @actor_app=p_actor;
    UPDATE encuesta SET estado=p_estado WHERE id_encuesta=p_id_encuesta;
    SET @actor_app=NULL;
END$$

-- =========================================================
-- e. TRIGGERS  (validación e inmutabilidad)
-- =========================================================

DROP TRIGGER IF EXISTS trg_pregunta_validar_bi$$
CREATE TRIGGER trg_pregunta_validar_bi
BEFORE INSERT ON pregunta_encuesta
FOR EACH ROW
BEGIN
    CALL sp_validar_pregunta(NEW.tipo, NEW.opciones_json);
END$$

DROP TRIGGER IF EXISTS trg_pregunta_validar_bu$$
CREATE TRIGGER trg_pregunta_validar_bu
BEFORE UPDATE ON pregunta_encuesta
FOR EACH ROW
BEGIN
    CALL sp_validar_pregunta(NEW.tipo, NEW.opciones_json);
END$$

-- Solo se aceptan respuestas para encuestas vigentes.
DROP TRIGGER IF EXISTS trg_respuesta_validar_bi$$
CREATE TRIGGER trg_respuesta_validar_bi
BEFORE INSERT ON respuesta_encuesta
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM encuesta
        WHERE id_encuesta=NEW.id_encuesta
          AND fn_encuesta_vigente(estado,disponible_desde,disponible_hasta)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La encuesta no está disponible.';
    END IF;
END$$

-- La pregunta debe pertenecer a la encuesta respondida y el valor debe corresponder a su tipo.
DROP TRIGGER IF EXISTS trg_detalle_validar_bi$$
CREATE TRIGGER trg_detalle_validar_bi
BEFORE INSERT ON detalle_respuesta_encuesta
FOR EACH ROW
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_tipo VARCHAR(10);
    DECLARE v_opciones JSON;

    SELECT COUNT(*) INTO v_existe
    FROM pregunta_encuesta p
    JOIN respuesta_encuesta r ON r.id_encuesta=p.id_encuesta
    WHERE p.id_pregunta=NEW.id_pregunta AND r.id_respuesta=NEW.id_respuesta;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La pregunta no pertenece a la encuesta respondida.';
    END IF;

    SELECT tipo, opciones_json INTO v_tipo, v_opciones
    FROM pregunta_encuesta WHERE id_pregunta=NEW.id_pregunta;

    IF (v_tipo='ESCALA' AND fn_valor_escala(NEW.valor_json) IS NULL)
       OR (v_tipo='TEXTO' AND (JSON_TYPE(NEW.valor_json)<>'STRING'
                               OR CHAR_LENGTH(JSON_UNQUOTE(NEW.valor_json)) NOT BETWEEN 1 AND 2000))
       OR (v_tipo='UNICA' AND (JSON_TYPE(NEW.valor_json)<>'STRING'
                               OR NOT JSON_CONTAINS(v_opciones,NEW.valor_json)))
       OR (v_tipo='MULTIPLE' AND (JSON_TYPE(NEW.valor_json)<>'ARRAY'
                                  OR JSON_LENGTH(NEW.valor_json)=0
                                  OR NOT JSON_CONTAINS(v_opciones,NEW.valor_json))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El valor no corresponde al tipo de la pregunta.';
    END IF;
END$$

-- Las respuestas enviadas son inmutables (integridad de los resultados).
DROP TRIGGER IF EXISTS trg_respuesta_bloquear_bu$$
CREATE TRIGGER trg_respuesta_bloquear_bu
BEFORE UPDATE ON respuesta_encuesta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las respuestas de encuesta no se modifican.';
END$$

DROP TRIGGER IF EXISTS trg_respuesta_bloquear_bd$$
CREATE TRIGGER trg_respuesta_bloquear_bd
BEFORE DELETE ON respuesta_encuesta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las respuestas de encuesta no se eliminan.';
END$$

DROP TRIGGER IF EXISTS trg_detalle_bloquear_bu$$
CREATE TRIGGER trg_detalle_bloquear_bu
BEFORE UPDATE ON detalle_respuesta_encuesta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las respuestas de encuesta no se modifican.';
END$$

DROP TRIGGER IF EXISTS trg_detalle_bloquear_bd$$
CREATE TRIGGER trg_detalle_bloquear_bd
BEFORE DELETE ON detalle_respuesta_encuesta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las respuestas de encuesta no se eliminan.';
END$$

-- =========================================================
-- m. AUDITORÍAS  (triggers → historial_gestion, igual que el modelo base)
-- La clave de edición (hash) nunca se copia al historial.
-- =========================================================

DROP TRIGGER IF EXISTS trg_contacto_perfil_auditar_ai$$
CREATE TRIGGER trg_contacto_perfil_auditar_ai
AFTER INSERT ON contacto_perfil
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'CREAR_CONTACTO',
        CONCAT('contacto_perfil:',NEW.id_cuenta),
        NULL,
        JSON_OBJECT('id_cuenta',NEW.id_cuenta,'correo',NEW.correo,
                    'telefono',NEW.telefono,'medio_preferido',NEW.medio_preferido)
    );
END$$

DROP TRIGGER IF EXISTS trg_contacto_perfil_auditar_au$$
CREATE TRIGGER trg_contacto_perfil_auditar_au
AFTER UPDATE ON contacto_perfil
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_CONTACTO',
        CONCAT('contacto_perfil:',NEW.id_cuenta),
        JSON_OBJECT('correo',OLD.correo,'telefono',OLD.telefono,'medio_preferido',OLD.medio_preferido),
        JSON_OBJECT('correo',NEW.correo,'telefono',NEW.telefono,'medio_preferido',NEW.medio_preferido)
    );
END$$

DROP TRIGGER IF EXISTS trg_encuesta_auditar_ai$$
CREATE TRIGGER trg_encuesta_auditar_ai
AFTER INSERT ON encuesta
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'CREAR_ENCUESTA',
        CONCAT('encuesta:',NEW.id_encuesta),
        NULL,
        JSON_OBJECT('titulo',NEW.titulo,'version_encuesta',NEW.version_encuesta,'estado',NEW.estado,
                    'disponible_desde',NEW.disponible_desde,'disponible_hasta',NEW.disponible_hasta)
    );
END$$

DROP TRIGGER IF EXISTS trg_encuesta_auditar_au$$
CREATE TRIGGER trg_encuesta_auditar_au
AFTER UPDATE ON encuesta
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_ENCUESTA',
        CONCAT('encuesta:',NEW.id_encuesta),
        JSON_OBJECT('titulo',OLD.titulo,'version_encuesta',OLD.version_encuesta,'estado',OLD.estado,
                    'disponible_desde',OLD.disponible_desde,'disponible_hasta',OLD.disponible_hasta),
        JSON_OBJECT('titulo',NEW.titulo,'version_encuesta',NEW.version_encuesta,'estado',NEW.estado,
                    'disponible_desde',NEW.disponible_desde,'disponible_hasta',NEW.disponible_hasta)
    );
END$$

DROP TRIGGER IF EXISTS trg_pregunta_auditar_au$$
CREATE TRIGGER trg_pregunta_auditar_au
AFTER UPDATE ON pregunta_encuesta
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'ACTUALIZAR_PREGUNTA',
        CONCAT('pregunta_encuesta:',NEW.id_pregunta),
        JSON_OBJECT('numero',OLD.numero,'texto',OLD.texto,'tipo',OLD.tipo,
                    'obligatoria',OLD.obligatoria,'opciones_json',OLD.opciones_json),
        JSON_OBJECT('numero',NEW.numero,'texto',NEW.texto,'tipo',NEW.tipo,
                    'obligatoria',NEW.obligatoria,'opciones_json',NEW.opciones_json)
    );
END$$

-- Solo se registra el envío (no el contenido) para no exponer respuestas en el historial.
DROP TRIGGER IF EXISTS trg_respuesta_auditar_ai$$
CREATE TRIGGER trg_respuesta_auditar_ai
AFTER INSERT ON respuesta_encuesta
FOR EACH ROW
BEGIN
    INSERT INTO historial_gestion(fecha,actor,accion,elemento_afectado,antes,despues)
    VALUES(
        CURRENT_TIMESTAMP,
        COALESCE(NULLIF(@actor_app,''),CURRENT_USER()),
        'RESPONDER_ENCUESTA',
        CONCAT('respuesta_encuesta:',NEW.id_respuesta),
        NULL,
        JSON_OBJECT('id_encuesta',NEW.id_encuesta,'anonima',NEW.id_contacto IS NULL)
    );
END$$

DELIMITER ;

-- =========================================================
-- d. REGISTROS INICIALES
-- Encuesta de usabilidad del proyecto (5 afirmaciones, escala 1-5).
-- =========================================================

INSERT IGNORE INTO encuesta (id_encuesta,titulo,descripcion,version_encuesta,estado) VALUES
('travesias-usabilidad-v1','Encuesta de usabilidad',
 'Cuéntanos cómo fue tu experiencia en Travesías Conecta. Selecciona una respuesta por afirmación.',1,'ACTIVA');

INSERT IGNORE INTO pregunta_encuesta (id_encuesta,numero,texto,tipo,obligatoria) VALUES
('travesias-usabilidad-v1',1,'Me resultó fácil aprender a utilizar este subproyecto.','ESCALA',TRUE),
('travesias-usabilidad-v1',2,'Pude encontrar fácilmente las opciones y funciones que necesitaba.','ESCALA',TRUE),
('travesias-usabilidad-v1',3,'La información y los textos de la interfaz fueron claros y comprensibles.','ESCALA',TRUE),
('travesias-usabilidad-v1',4,'Logré realizar las tareas que necesitaba sin dificultades innecesarias.','ESCALA',TRUE),
('travesias-usabilidad-v1',5,'En general, estoy satisfecho con la experiencia de uso de este subproyecto.','ESCALA',TRUE);

-- No se insertan contactos ni respuestas ficticias: se crean desde la app.

-- =========================================================
-- i. VISTAS  (l. datos calculados)
-- =========================================================

-- Contactos para la Junta, sin la clave de edición.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_contactos_perfil AS
SELECT
    c.id_cuenta,
    c.nombre,
    c.estado,
    p.correo,
    p.telefono,
    p.medio_preferido,
    p.creado_en,
    p.actualizado_en
FROM contacto_perfil p
JOIN cuenta_acceso c ON c.id_cuenta=p.id_cuenta;

-- Encuestas que la app puede mostrar, con totales calculados.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_encuestas_vigentes AS
SELECT
    e.id_encuesta,
    e.titulo,
    e.descripcion,
    e.version_encuesta,
    e.disponible_hasta,
    (SELECT COUNT(*) FROM pregunta_encuesta p WHERE p.id_encuesta=e.id_encuesta) AS total_preguntas,
    (SELECT COUNT(*) FROM respuesta_encuesta r WHERE r.id_encuesta=e.id_encuesta) AS total_respuestas
FROM encuesta e
WHERE fn_encuesta_vigente(e.estado,e.disponible_desde,e.disponible_hasta);

-- Resultados por pregunta: total, promedio (1-5) y % favorable (respuestas 4 o 5).
CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_resultados_encuesta AS
SELECT
    p.id_encuesta,
    p.id_pregunta,
    p.numero,
    p.texto,
    p.tipo,
    COUNT(d.id_detalle) AS total_respuestas,
    CASE WHEN p.tipo='ESCALA'
         THEN ROUND(AVG(fn_valor_escala(d.valor_json)),2) END AS promedio,
    CASE WHEN p.tipo='ESCALA'
         THEN ROUND(100*SUM(fn_valor_escala(d.valor_json)>=4)/NULLIF(COUNT(d.id_detalle),0),1) END AS porcentaje_favorable
FROM pregunta_encuesta p
LEFT JOIN detalle_respuesta_encuesta d ON d.id_pregunta=p.id_pregunta
GROUP BY p.id_encuesta,p.id_pregunta,p.numero,p.texto,p.tipo;

-- Auditoría de los objetos de esta extensión.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW vw_auditoria_extension AS
SELECT fecha,actor,accion,elemento_afectado,antes,despues
FROM historial_gestion
WHERE elemento_afectado LIKE 'contacto_perfil:%'
   OR elemento_afectado LIKE 'encuesta:%'
   OR elemento_afectado LIKE 'pregunta_encuesta:%'
   OR elemento_afectado LIKE 'respuesta_encuesta:%';

-- =========================================================
-- j. ÍNDICES
-- Declarados dentro de cada CREATE TABLE para que el script sea re-ejecutable
-- (MySQL no admite CREATE INDEX IF NOT EXISTS):
--   uq_contacto_clave_hash, idx_contacto_correo, idx_encuesta_vigencia,
--   uq_pregunta_orden, uq_encuesta_contacto, idx_respuesta_fecha,
--   uq_detalle_pregunta, idx_detalle_pregunta (+ índices de las FK).
-- =========================================================

-- =========================================================
-- h. SINÓNIMOS: OMITIDO
-- MySQL no tiene CREATE SYNONYM al estilo Oracle. Las vistas cumplen ese papel.
-- =========================================================

-- =========================================================
-- k. SECUENCIAS: OMITIDO como objeto
-- id_pregunta, id_respuesta e id_detalle usan AUTO_INCREMENT.
-- id_cuenta del contacto lo genera la API (con-<UUID>), como los demás IDs VARCHAR(64).
-- =========================================================

-- =========================================================
-- l. DATOS CALCULADOS
--   fn_encuesta_vigente ........ vigencia de una encuesta
--   fn_valor_escala ............ puntaje 1-5 de una respuesta
--   vw_encuestas_vigentes ...... total_preguntas, total_respuestas
--   vw_resultados_encuesta ..... total_respuestas, promedio, porcentaje_favorable
--   contacto_perfil.actualizado_en (ON UPDATE CURRENT_TIMESTAMP)
-- =========================================================

-- =========================================================
-- PERMISOS
-- r_tc_backend y r_tc_admin ya tienen acceso a sihaychamba.* por el modelo base.
-- r_tc_lectura solo puede ver las encuestas vigentes.
-- =========================================================
GRANT SELECT ON sihaychamba.vw_encuestas_vigentes TO 'r_tc_lectura';
GRANT EXECUTE ON FUNCTION sihaychamba.fn_encuesta_vigente TO 'r_tc_lectura';

-- =========================================================
-- VERSIÓN DEL ESQUEMA
-- =========================================================

CREATE TABLE IF NOT EXISTS migracion_esquema (
    version VARCHAR(20) NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    aplicada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_migracion_esquema PRIMARY KEY (version)
) ENGINE=InnoDB;

-- Permiso explícito para el backend: sigue funcionando aunque se restrinja el rol
-- (como en 003_permisos_backend.sql) en lugar de SELECT/EXECUTE sobre todo el esquema.
SET @sh_rol = (SELECT COUNT(*) FROM mysql.user WHERE User = 'r_tc_backend' AND Host IN ('%', ''));
SET @sh_sql = IF(@sh_rol > 0,
    CONCAT('GRANT EXECUTE ON PROCEDURE `', DATABASE(), '`.sp_crear_publicacion TO ''r_tc_backend'''),
    'DO 0');
PREPARE s FROM @sh_sql;
EXECUTE s;
DEALLOCATE PREPARE s;

INSERT IGNORE INTO migracion_esquema (version, descripcion)
VALUES ('004', 'Publicación directa sin aprobación: fecha_publicacion, sp_crear_publicacion');

DROP PROCEDURE IF EXISTS sh_agregar_fecha_publicacion;
DROP PROCEDURE IF EXISTS sh_crear_indice;
SET @actor_app = NULL;
SET SESSION sql_safe_updates = @sh_safe_updates;

-- =========================================================
-- VERIFICACIÓN (solo lectura)
-- =========================================================

SELECT version, aplicada_en FROM migracion_esquema;
SELECT COUNT(*) AS publicaciones_sin_fecha FROM publicacion WHERE fecha_publicacion IS NULL;  -- debe ser 0
SELECT id_publicacion, titulo, fecha_publicacion FROM vw_publicaciones_vigentes
ORDER BY fecha_publicacion DESC, id_publicacion DESC;
