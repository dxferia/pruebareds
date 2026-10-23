-- Ejecutar con una cuenta administradora DESPUÉS de las migraciones.
-- El rol original concede SELECT y EXECUTE globales. Se reducen esos privilegios
-- para evitar acceso a los procedimientos administrativos.
USE travesias_conecta;
REVOKE SELECT, EXECUTE ON travesias_conecta.* FROM 'r_tc_backend';
GRANT SELECT ON travesias_conecta.publicacion TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.solicitud_publicacion TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.solicitud_contacto TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.categoria TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.metodo_pago TO 'r_tc_backend';
GRANT SELECT, INSERT, UPDATE(nombre) ON travesias_conecta.cuenta_acceso TO 'r_tc_backend';
GRANT SELECT, INSERT, UPDATE(correo, telefono, medio_preferido) ON travesias_conecta.contacto_perfil TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.vw_publicaciones_vigentes TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.vw_solicitudes_publicacion TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.vw_solicitudes_contacto TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.encuesta TO 'r_tc_backend';
GRANT SELECT ON travesias_conecta.pregunta_encuesta TO 'r_tc_backend';
GRANT SELECT, INSERT ON travesias_conecta.respuesta_encuesta TO 'r_tc_backend';
GRANT INSERT ON travesias_conecta.detalle_respuesta_encuesta TO 'r_tc_backend';
GRANT EXECUTE ON PROCEDURE travesias_conecta.sp_crear_solicitud_publicacion TO 'r_tc_backend';
GRANT EXECUTE ON PROCEDURE travesias_conecta.sp_crear_solicitud_contacto TO 'r_tc_backend';
