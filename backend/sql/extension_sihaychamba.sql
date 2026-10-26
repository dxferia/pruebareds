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
