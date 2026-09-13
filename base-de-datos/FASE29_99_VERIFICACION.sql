-- ============================================================
-- FASE 29 - VERIFICACION DE INSTALACION (SOLO LECTURA)
-- Puede ejecutarse despues de todos los scripts.
-- ============================================================

-- A) Tablas esperadas
select tablename
from pg_tables
where schemaname = 'public'
  and tablename in (
    'perfiles','eventos','inscripciones_evento','salas','actividades',
    'credenciales_qr','sesiones_presencia','certificados',
    'contenido_sitio','tarifas_fase29','pagos_fase29'
  )
order by tablename;

-- B) Funciones/RPC principales
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'inscribirse_evento','verificar_pago_evento','inscribirse_actividad',
    'obtener_o_crear_qr','registrar_escaneo_sala','mi_asistencia_evento',
    'mi_elegibilidad_certificado','emitir_mi_certificado','verificar_certificado',
    'registrar_referencia_pago_evento','eliminar_mi_cuenta',
    'estadisticas_publicas_evento','cupos_publicos_talleres_evento'
  )
order by routine_name;

-- C) RLS habilitado
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

-- D) Permiso anon que evita el error 42501/401 observado en la primera integracion
select
  has_schema_privilege('anon', 'private', 'USAGE') as anon_schema_private_ok,
  has_function_privilege('anon','private.usuario_tiene_rol(text[])','EXECUTE') as anon_rol_helper_ok;

-- E) Evento y tarifas demo
select id, nombre, slug, estado, es_prueba, inscripciones_abiertas, requiere_pago,
       fecha_inicio, fecha_fin
from public.eventos
where slug = 'coneic-huancayo-2027';

select t.clave, t.nombre, t.monto, t.activo
from public.tarifas_fase29 t
join public.eventos e on e.id = t.evento_id
where e.slug = 'coneic-huancayo-2027'
order by t.monto;

-- F) Resumen de perfiles por rol (no muestra contraseñas; Auth no las expone)
select rol, activo, count(*) as cantidad
from public.perfiles
group by rol, activo
order by rol, activo;
