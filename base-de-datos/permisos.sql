-- ============================================================
-- BASE DE DATOS V3 - SEGURIDAD / RLS / GRANTS
-- Archivo: permisos.sql
-- Ejecutar DESPUÉS de funciones.sql
-- ============================================================

-- ============================================================
-- 1. ACTIVAR RLS
-- ============================================================

alter table public.perfiles enable row level security;
alter table public.eventos enable row level security;
alter table public.inscripciones_evento enable row level security;
alter table public.salas enable row level security;
alter table public.actividades enable row level security;
alter table public.ponentes enable row level security;
alter table public.actividad_ponentes enable row level security;
alter table public.equipos enable row level security;
alter table public.miembros_equipo enable row level security;
alter table public.inscripciones_actividad enable row level security;
alter table public.credenciales_qr enable row level security;
alter table public.cursos enable row level security;
alter table public.curso_participantes enable row level security;
alter table public.asignaciones_asistencia_curso enable row level security;
alter table public.sesiones_presencia enable row level security;
alter table public.certificados enable row level security;

-- ============================================================
-- 2. PRIVILEGIOS DE FUNCIONES
-- Por defecto Postgres permite ejecutar funciones a PUBLIC.
-- Aquí se revoca y después se concede solo lo necesario.
-- ============================================================

revoke execute on all functions in schema public from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;

alter default privileges in schema public
revoke execute on functions from public, anon, authenticated;

alter default privileges in schema private
revoke execute on functions from public, anon, authenticated;

-- El schema privado NO se expone en la API.
-- Solo se concede USAGE para que los wrappers públicos puedan llamar
-- funciones internas con SECURITY INVOKER.
grant usage on schema private to anon, authenticated;

-- Helpers necesarios para políticas.
grant execute on function private.usuario_tiene_rol(text[]) to authenticated;
grant execute on function private.usuario_esta_activo() to authenticated;
grant execute on function private.usuario_pertenece_equipo(uuid) to authenticated;

-- Implementaciones privadas invocadas por wrappers autenticados.
grant execute on function private.inscribirse_evento_impl(uuid) to authenticated;
grant execute on function private.verificar_pago_evento_impl(uuid, boolean, text) to authenticated;
grant execute on function private.inscribirse_actividad_impl(uuid) to authenticated;
grant execute on function private.crear_equipo_impl(uuid, text) to authenticated;
grant execute on function private.unirse_equipo_impl(uuid) to authenticated;
grant execute on function private.inscribir_equipo_actividad_impl(uuid) to authenticated;
grant execute on function private.obtener_o_crear_qr_impl(uuid) to authenticated;
grant execute on function private.regenerar_qr_impl(uuid) to authenticated;
grant execute on function private.agregar_mi_curso_impl(uuid) to authenticated;
grant execute on function private.seleccionar_curso_asistencia_impl(uuid, uuid) to authenticated;
grant execute on function private.quitar_curso_asistencia_impl(uuid, uuid) to authenticated;
grant execute on function private.registrar_escaneo_sala_impl(uuid, uuid) to authenticated;
grant execute on function private.calcular_presencia_actividad_impl(uuid, uuid) to authenticated;
grant execute on function private.mi_asistencia_evento_impl(uuid) to authenticated;
grant execute on function private.reporte_asistencia_curso_impl(uuid, uuid) to authenticated;
grant execute on function private.calcular_elegibilidad_certificado_impl(uuid, uuid) to authenticated;
grant execute on function private.mi_elegibilidad_certificado_impl(uuid) to authenticated;
grant execute on function private.emitir_mi_certificado_impl(uuid) to authenticated;
grant execute on function private.emitir_certificado_manual_impl(uuid, uuid, text, uuid, text) to authenticated;

-- Verificación pública.
grant execute on function private.verificar_certificado_impl(text) to anon, authenticated;

-- Wrappers públicos.
grant execute on function public.inscribirse_evento(uuid) to authenticated;
grant execute on function public.verificar_pago_evento(uuid, boolean, text) to authenticated;
grant execute on function public.inscribirse_actividad(uuid) to authenticated;
grant execute on function public.crear_equipo(uuid, text) to authenticated;
grant execute on function public.unirse_equipo(uuid) to authenticated;
grant execute on function public.inscribir_equipo_actividad(uuid) to authenticated;
grant execute on function public.obtener_o_crear_qr(uuid) to authenticated;
grant execute on function public.regenerar_qr(uuid) to authenticated;
grant execute on function public.agregar_mi_curso(uuid) to authenticated;
grant execute on function public.seleccionar_curso_asistencia(uuid, uuid) to authenticated;
grant execute on function public.quitar_curso_asistencia(uuid, uuid) to authenticated;
grant execute on function public.registrar_escaneo_sala(uuid, uuid) to authenticated;
grant execute on function public.mi_asistencia_evento(uuid) to authenticated;
grant execute on function public.reporte_asistencia_curso(uuid, uuid) to authenticated;
grant execute on function public.mi_elegibilidad_certificado(uuid) to authenticated;
grant execute on function public.emitir_mi_certificado(uuid) to authenticated;
grant execute on function public.emitir_certificado_manual(uuid, uuid, text, uuid, text) to authenticated;
grant execute on function public.verificar_certificado(text) to anon, authenticated;

-- ============================================================
-- 3. PRIVILEGIOS DE TABLAS
-- RLS sigue siendo la barrera que decide las filas permitidas.
-- ============================================================

grant select on public.eventos, public.salas, public.actividades,
    public.ponentes, public.actividad_ponentes
to anon;

grant select, insert, update, delete
on all tables in schema public
to authenticated;

-- ============================================================
-- 4. PERFILES
-- ============================================================

create policy "perfil: usuario o admin puede leer"
on public.perfiles
for select
to authenticated
using (
    id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "perfil: usuario o admin puede actualizar"
on public.perfiles
for update
to authenticated
using (
    id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 5. EVENTOS
-- Anónimo: solo eventos reales publicados.
-- Autenticado: eventos publicados (incluye pruebas) o todo si es admin.
-- ============================================================

create policy "eventos: anon ve publicados reales"
on public.eventos
for select
to anon
using (
    estado = 'publicado'
    and es_prueba = false
);

create policy "eventos: autenticado ve publicados"
on public.eventos
for select
to authenticated
using (
    estado = 'publicado'
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "eventos: admin inserta"
on public.eventos
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "eventos: admin actualiza"
on public.eventos
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "eventos: admin elimina"
on public.eventos
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);


-- ============================================================
-- 6. SALAS
-- ============================================================

create policy "salas: anon ve activas de eventos reales publicados"
on public.salas
for select
to anon
using (
    activo = true
    and exists (
        select 1
        from public.eventos e
        where e.id = salas.evento_id
          and e.estado = 'publicado'
          and e.es_prueba = false
    )
);

create policy "salas: autenticado ve activas"
on public.salas
for select
to authenticated
using (
    activo = true
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "salas: admin inserta"
on public.salas
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "salas: admin actualiza"
on public.salas
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "salas: admin elimina"
on public.salas
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 7. ACTIVIDADES
-- ============================================================

create policy "actividades: anon ve publicadas reales"
on public.actividades
for select
to anon
using (
    estado = 'publicado'
    and exists (
        select 1
        from public.eventos e
        where e.id = actividades.evento_id
          and e.estado = 'publicado'
          and e.es_prueba = false
    )
);

create policy "actividades: autenticado ve publicadas"
on public.actividades
for select
to authenticated
using (
    (
        estado = 'publicado'
        and exists (
            select 1
            from public.eventos e
            where e.id = actividades.evento_id
              and e.estado = 'publicado'
        )
    )
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "actividades: admin inserta"
on public.actividades
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "actividades: admin actualiza"
on public.actividades
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "actividades: admin elimina"
on public.actividades
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 7. PONENTES
-- Evita publicar ponentes que todavía no estén asociados
-- a una actividad publicada.
-- ============================================================

create policy "ponentes: anon ve anunciados"
on public.ponentes
for select
to anon
using (
    exists (
        select 1
        from public.actividad_ponentes ap
        join public.actividades a on a.id = ap.actividad_id
        join public.eventos e on e.id = a.evento_id
        where ap.ponente_id = ponentes.id
          and a.estado = 'publicado'
          and e.estado = 'publicado'
          and e.es_prueba = false
    )
);

create policy "ponentes: autenticado ve anunciados"
on public.ponentes
for select
to authenticated
using (
    exists (
        select 1
        from public.actividad_ponentes ap
        join public.actividades a on a.id = ap.actividad_id
        join public.eventos e on e.id = a.evento_id
        where ap.ponente_id = ponentes.id
          and a.estado = 'publicado'
          and e.estado = 'publicado'
    )
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "ponentes: admin inserta"
on public.ponentes
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "ponentes: admin actualiza"
on public.ponentes
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "ponentes: admin elimina"
on public.ponentes
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 8. ACTIVIDAD-PONENTES
-- ============================================================

create policy "actividad ponentes: anon ve relaciones publicadas"
on public.actividad_ponentes
for select
to anon
using (
    exists (
        select 1
        from public.actividades a
        join public.eventos e on e.id = a.evento_id
        where a.id = actividad_ponentes.actividad_id
          and a.estado = 'publicado'
          and e.estado = 'publicado'
          and e.es_prueba = false
    )
);

create policy "actividad ponentes: autenticado ve relaciones publicadas"
on public.actividad_ponentes
for select
to authenticated
using (
    exists (
        select 1
        from public.actividades a
        join public.eventos e on e.id = a.evento_id
        where a.id = actividad_ponentes.actividad_id
          and a.estado = 'publicado'
          and e.estado = 'publicado'
    )
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "actividad ponentes: admin inserta"
on public.actividad_ponentes
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "actividad ponentes: admin elimina"
on public.actividad_ponentes
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 9. INSCRIPCIONES GENERALES
-- ============================================================

create policy "inscripcion evento: usuario o admin lee"
on public.inscripciones_evento
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "inscripcion evento: admin actualiza"
on public.inscripciones_evento
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 10. EQUIPOS
-- ============================================================

create policy "equipos: miembro o admin lee"
on public.equipos
for select
to authenticated
using (
    private.usuario_pertenece_equipo(id)
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "equipos: admin actualiza"
on public.equipos
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "equipos: admin elimina"
on public.equipos
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "miembros equipo: miembro o admin lee"
on public.miembros_equipo
for select
to authenticated
using (
    private.usuario_pertenece_equipo(equipo_id)
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "miembros equipo: admin actualiza"
on public.miembros_equipo
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "miembros equipo: admin elimina"
on public.miembros_equipo
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 11. INSCRIPCIONES A ACTIVIDADES
-- ============================================================

create policy "inscripcion actividad: usuario equipo o admin lee"
on public.inscripciones_actividad
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (
        equipo_id is not null
        and private.usuario_pertenece_equipo(equipo_id)
    )
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "inscripcion actividad: admin actualiza"
on public.inscripciones_actividad
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "inscripcion actividad: admin elimina"
on public.inscripciones_actividad
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 12. QR
-- ============================================================

create policy "qr: usuario o admin lee"
on public.credenciales_qr
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "qr: admin actualiza"
on public.credenciales_qr
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 13. CURSOS
-- ============================================================

create policy "cursos: autenticado ve activos"
on public.cursos
for select
to authenticated
using (
    activo = true
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "cursos: admin inserta"
on public.cursos
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "cursos: admin actualiza"
on public.cursos
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "cursos: admin elimina"
on public.cursos
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 14. PARTICIPANTES DE CURSOS
-- ============================================================

create policy "curso participantes: usuario o admin lee"
on public.curso_participantes
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "curso participantes: admin administra"
on public.curso_participantes
for all
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 15. ASIGNACIONES DE ASISTENCIA A CURSOS
-- ============================================================

create policy "asignacion curso: usuario o admin lee"
on public.asignaciones_asistencia_curso
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "asignacion curso: admin administra"
on public.asignaciones_asistencia_curso
for all
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 16. SESIONES DE PRESENCIA
-- Control registra por RPC; el participante solo consulta las suyas.
-- ============================================================

create policy "sesion presencia: usuario o admin lee"
on public.sesiones_presencia
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "sesion presencia: admin inserta"
on public.sesiones_presencia
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "sesion presencia: admin actualiza"
on public.sesiones_presencia
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "sesion presencia: admin elimina"
on public.sesiones_presencia
for delete
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- ============================================================
-- 14. CERTIFICADOS
-- ============================================================

create policy "certificado: usuario o admin lee"
on public.certificados
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "certificado: admin inserta"
on public.certificados
for insert
to authenticated
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "certificado: admin actualiza"
on public.certificados
for update
to authenticated
using (
    (select private.usuario_tiene_rol(array['admin']::text[]))
)
with check (
    (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- No se expone DELETE por aplicación para conservar historial.
