-- Ejecutar con una cuenta administradora DESPUÉS de las migraciones.
-- El rol original concede SELECT y EXECUTE globales. Se reducen esos privilegios
-- para evitar acceso a los procedimientos administrativos.
USE servicio_chamba;
REVOKE SELECT, EXECUTE ON servicio_chamba.* FROM 'r_tc_backend';
GRANT SELECT ON servicio_chamba.publicacion TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.solicitud_publicacion TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.solicitud_contacto TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.categoria TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.metodo_pago TO 'r_tc_backend';
GRANT SELECT, INSERT, UPDATE(nombre) ON servicio_chamba.cuenta_acceso TO 'r_tc_backend';
GRANT SELECT, INSERT, UPDATE(correo, telefono, medio_preferido) ON servicio_chamba.contacto_perfil TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.vw_publicaciones_vigentes TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.vw_solicitudes_publicacion TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.vw_solicitudes_contacto TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.encuesta TO 'r_tc_backend';
GRANT SELECT ON servicio_chamba.pregunta_encuesta TO 'r_tc_backend';
GRANT SELECT, INSERT ON servicio_chamba.respuesta_encuesta TO 'r_tc_backend';
GRANT INSERT ON servicio_chamba.detalle_respuesta_encuesta TO 'r_tc_backend';
GRANT EXECUTE ON PROCEDURE servicio_chamba.sp_crear_solicitud_publicacion TO 'r_tc_backend';
GRANT EXECUTE ON PROCEDURE servicio_chamba.sp_crear_solicitud_contacto TO 'r_tc_backend';
