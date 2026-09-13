-- ============================================================
-- V3.2 - PERMISOS NUEVOS DESPUÉS DE MIGRAR DESDE V3.1
-- ============================================================

alter table public.salas enable row level security;
alter table public.cursos enable row level security;
alter table public.curso_participantes enable row level security;
alter table public.asignaciones_asistencia_curso enable row level security;
alter table public.sesiones_presencia enable row level security;

grant select, insert, update, delete
on public.salas,
   public.cursos,
   public.curso_participantes,
   public.asignaciones_asistencia_curso,
   public.sesiones_presencia
to authenticated;

grant select on public.salas to anon;

grant usage on schema private to anon, authenticated;

grant execute on function private.agregar_mi_curso_impl(uuid) to authenticated;
grant execute on function private.seleccionar_curso_asistencia_impl(uuid, uuid) to authenticated;
grant execute on function private.quitar_curso_asistencia_impl(uuid, uuid) to authenticated;
grant execute on function private.registrar_escaneo_sala_impl(uuid, uuid) to authenticated;
grant execute on function private.calcular_presencia_actividad_impl(uuid, uuid) to authenticated;
grant execute on function private.mi_asistencia_evento_impl(uuid) to authenticated;
grant execute on function private.reporte_asistencia_curso_impl(uuid, uuid) to authenticated;

grant execute on function public.agregar_mi_curso(uuid) to authenticated;
grant execute on function public.seleccionar_curso_asistencia(uuid, uuid) to authenticated;
grant execute on function public.quitar_curso_asistencia(uuid, uuid) to authenticated;
grant execute on function public.registrar_escaneo_sala(uuid, uuid) to authenticated;
grant execute on function public.mi_asistencia_evento(uuid) to authenticated;
grant execute on function public.reporte_asistencia_curso(uuid, uuid) to authenticated;

create policy "salas: anon ve activas de eventos reales publicados"
on public.salas for select to anon
using (
    activo = true
    and exists (
        select 1 from public.eventos e
        where e.id = salas.evento_id
          and e.estado = 'publicado'
          and e.es_prueba = false
    )
);

create policy "salas: autenticado ve activas"
on public.salas for select to authenticated
using (
    activo = true
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "salas: admin administra"
on public.salas for all to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

create policy "cursos: autenticado ve activos"
on public.cursos for select to authenticated
using (
    activo = true
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "cursos: admin administra"
on public.cursos for all to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

create policy "curso participantes: usuario o admin lee"
on public.curso_participantes for select to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "curso participantes: admin administra"
on public.curso_participantes for all to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

create policy "asignacion curso: usuario o admin lee"
on public.asignaciones_asistencia_curso for select to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "asignacion curso: admin administra"
on public.asignaciones_asistencia_curso for all to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

create policy "sesion presencia: usuario o admin lee"
on public.sesiones_presencia for select to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

create policy "sesion presencia: admin administra"
on public.sesiones_presencia for all to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));
