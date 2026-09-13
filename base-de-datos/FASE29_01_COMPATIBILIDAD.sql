-- ============================================================
-- FASE 29 - COMPATIBILIDAD DE LECTURA PUBLICA
-- Ejecutar DESPUES de:
--   1) esquema.sql
--   2) funciones.sql
--   3) permisos.sql
--
-- NO modifica tablas ni funciones estructurales. Corrige un permiso requerido
-- por las politicas RLS publicas que evalúan private.usuario_tiene_rol(...)
-- para usuarios anonimos.
-- ============================================================

-- permisos.sql ya concede USAGE, pero repetimos el GRANT de forma idempotente.
grant usage on schema private to anon, authenticated;

-- Algunas politicas SELECT publicas contienen:
--   ... OR private.usuario_tiene_rol(array['admin'])
-- PostgreSQL debe poder evaluar la funcion incluso cuando auth.uid() es NULL.
-- Para anon la funcion simplemente devuelve false; no concede rol alguno.
grant execute on function private.usuario_tiene_rol(text[]) to anon, authenticated;

-- Comprobacion rápida: ambas columnas deben resultar true.
select
  has_schema_privilege('anon', 'private', 'USAGE') as anon_schema_private_ok,
  has_function_privilege(
    'anon',
    'private.usuario_tiene_rol(text[])',
    'EXECUTE'
  ) as anon_usuario_tiene_rol_ok;
