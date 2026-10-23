-- Ejecutar en Workbench DESPUÉS de bd_sihaychamba.sql (requiere cuenta_acceso).
-- No altera ni elimina las siete tablas originales; añade perfil de contacto.
USE sihaychamba;
CREATE TABLE IF NOT EXISTS contacto_perfil (
  id_cuenta VARCHAR(64) NOT NULL,
  correo VARCHAR(254) NOT NULL,
  telefono VARCHAR(30) NOT NULL,
  medio_preferido ENUM('LLAMADA','WHATSAPP','CORREO') NOT NULL DEFAULT 'WHATSAPP',
  clave_edicion_hash CHAR(64) NOT NULL,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY(id_cuenta),
  UNIQUE KEY uq_contacto_clave_hash (clave_edicion_hash),
  CONSTRAINT fk_contacto_cuenta FOREIGN KEY (id_cuenta)
    REFERENCES cuenta_acceso(id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;
