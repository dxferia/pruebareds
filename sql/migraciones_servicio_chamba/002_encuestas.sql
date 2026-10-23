-- El módulo recibido incluye cinco preguntas de usabilidad, reproducidas aquí literalmente.
-- Escala 1-5 y orden originales preservados. Las demás encuestas pueden configurarse en MySQL.
USE servicio_chamba;
CREATE TABLE IF NOT EXISTS encuesta (
  id_encuesta VARCHAR(64) NOT NULL,
  titulo VARCHAR(255) NOT NULL,
  descripcion TEXT NOT NULL,
  version_encuesta SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  estado ENUM('BORRADOR','ACTIVA','CERRADA') NOT NULL DEFAULT 'BORRADOR',
  disponible_desde DATETIME NULL,
  disponible_hasta DATETIME NULL,
  PRIMARY KEY(id_encuesta),
  CONSTRAINT chk_encuesta_periodo CHECK (disponible_hasta IS NULL OR disponible_desde IS NULL OR disponible_hasta >= disponible_desde)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pregunta_encuesta (
  id_pregunta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_encuesta VARCHAR(64) NOT NULL,
  numero SMALLINT UNSIGNED NOT NULL,
  texto TEXT NOT NULL,
  tipo ENUM('ESCALA','TEXTO','UNICA','MULTIPLE') NOT NULL,
  obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
  opciones_json JSON NULL,
  PRIMARY KEY(id_pregunta),
  UNIQUE KEY uq_pregunta_orden(id_encuesta,numero),
  CONSTRAINT fk_pregunta_encuesta FOREIGN KEY(id_encuesta)
    REFERENCES encuesta(id_encuesta) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS respuesta_encuesta (
  id_respuesta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_encuesta VARCHAR(64) NOT NULL,
  id_contacto VARCHAR(64) NULL,
  fecha_envio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(id_respuesta),
  UNIQUE KEY uq_encuesta_contacto(id_encuesta,id_contacto),
  KEY idx_respuesta_fecha(id_encuesta,fecha_envio),
  CONSTRAINT fk_respuesta_encuesta FOREIGN KEY(id_encuesta)
    REFERENCES encuesta(id_encuesta) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_respuesta_contacto FOREIGN KEY(id_contacto)
    REFERENCES cuenta_acceso(id_cuenta) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_respuesta_encuesta (
  id_detalle BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_respuesta BIGINT UNSIGNED NOT NULL,
  id_pregunta BIGINT UNSIGNED NOT NULL,
  valor_json JSON NOT NULL,
  PRIMARY KEY(id_detalle),
  UNIQUE KEY uq_detalle_pregunta(id_respuesta,id_pregunta),
  CONSTRAINT fk_detalle_respuesta FOREIGN KEY(id_respuesta)
    REFERENCES respuesta_encuesta(id_respuesta) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_detalle_pregunta FOREIGN KEY(id_pregunta)
    REFERENCES pregunta_encuesta(id_pregunta) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

INSERT IGNORE INTO encuesta (id_encuesta,titulo,descripcion,version_encuesta,estado)
VALUES ('travesias-usabilidad-v1','Encuesta de usabilidad',
'Cuéntanos cómo fue tu experiencia en Travesías Conecta. Selecciona una respuesta por afirmación.',1,'ACTIVA');

INSERT IGNORE INTO pregunta_encuesta (id_encuesta,numero,texto,tipo,obligatoria) VALUES
('travesias-usabilidad-v1',1,'Me resultó fácil aprender a utilizar este subproyecto.','ESCALA',TRUE),
('travesias-usabilidad-v1',2,'Pude encontrar fácilmente las opciones y funciones que necesitaba.','ESCALA',TRUE),
('travesias-usabilidad-v1',3,'La información y los textos de la interfaz fueron claros y comprensibles.','ESCALA',TRUE),
('travesias-usabilidad-v1',4,'Logré realizar las tareas que necesitaba sin dificultades innecesarias.','ESCALA',TRUE),
('travesias-usabilidad-v1',5,'En general, estoy satisfecho con la experiencia de uso de este subproyecto.','ESCALA',TRUE);
