-- ============================================================
-- INTEGRACIÓN VISUAL FASE 29 + BASE V3.2.1
-- Ejecutar DESPUÉS de: esquema.sql -> funciones.sql -> permisos.sql -> FASE29_01_COMPATIBILIDAD.sql
-- No modifica las tablas estructurales existentes.
-- Agrega únicamente soporte para contenido visual compartido y dos
-- operaciones que la interfaz Fase 29 necesita.
-- ============================================================

-- 1) Contenido editable del sitio (textos, temas, galería, FAQ, etc.)
create table if not exists public.contenido_sitio (
    clave text primary key,
    valor text not null default '{}',
    publico boolean not null default true,
    actualizado_por uuid references public.perfiles(id) on delete set null,
    actualizado_en timestamptz not null default now(),
    check (trim(clave) <> '')
);

alter table public.contenido_sitio enable row level security;

grant select on public.contenido_sitio to anon, authenticated;
grant insert, update, delete on public.contenido_sitio to authenticated;

drop policy if exists "contenido sitio: lectura publica" on public.contenido_sitio;
create policy "contenido sitio: lectura publica"
on public.contenido_sitio
for select
to anon, authenticated
using (
    publico = true
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

drop policy if exists "contenido sitio: admin inserta" on public.contenido_sitio;
create policy "contenido sitio: admin inserta"
on public.contenido_sitio
for insert
to authenticated
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

drop policy if exists "contenido sitio: admin actualiza" on public.contenido_sitio;
create policy "contenido sitio: admin actualiza"
on public.contenido_sitio
for update
to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

drop policy if exists "contenido sitio: admin elimina" on public.contenido_sitio;
create policy "contenido sitio: admin elimina"
on public.contenido_sitio
for delete
to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])));

insert into public.contenido_sitio (clave, valor, publico)
values ('site:content', '{}', true)
on conflict (clave) do nothing;

-- 2) Tarifas de entradas de Fase 29.
-- El precio autorizado vive en la base de datos. El navegador solo envía la
-- clave de la entrada; la RPC de pago obtiene el nombre y monto desde aquí.
create table if not exists public.tarifas_fase29 (
    evento_id uuid not null references public.eventos(id) on delete cascade,
    clave text not null,
    nombre text not null,
    monto numeric(10,2) not null check (monto >= 0),
    activo boolean not null default true,
    actualizado_por uuid references public.perfiles(id) on delete set null,
    actualizado_en timestamptz not null default now(),
    primary key (evento_id, clave),
    check (trim(clave) <> ''),
    check (trim(nombre) <> '')
);

alter table public.tarifas_fase29 enable row level security;
grant select on public.tarifas_fase29 to anon, authenticated;
grant insert, update, delete on public.tarifas_fase29 to authenticated;

drop policy if exists "tarifas fase29: lectura publica" on public.tarifas_fase29;
create policy "tarifas fase29: lectura publica"
on public.tarifas_fase29
for select
to anon, authenticated
using (
    (
      activo = true
      and exists (
        select 1 from public.eventos e
        where e.id = tarifas_fase29.evento_id
          and e.estado = 'publicado'
          and e.es_prueba = false
      )
    )
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

drop policy if exists "tarifas fase29: admin inserta" on public.tarifas_fase29;
create policy "tarifas fase29: admin inserta"
on public.tarifas_fase29
for insert
to authenticated
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

drop policy if exists "tarifas fase29: admin actualiza" on public.tarifas_fase29;
create policy "tarifas fase29: admin actualiza"
on public.tarifas_fase29
for update
to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])))
with check ((select private.usuario_tiene_rol(array['admin']::text[])));

drop policy if exists "tarifas fase29: admin elimina" on public.tarifas_fase29;
create policy "tarifas fase29: admin elimina"
on public.tarifas_fase29
for delete
to authenticated
using ((select private.usuario_tiene_rol(array['admin']::text[])));

-- 3) Detalle complementario de pago de la interfaz Fase 29.
-- La V3.2.1 conserva el estado/referencia en inscripciones_evento; esta tabla
-- añade tipo de entrada y monto para mostrar reportes coherentes sin cambiar
-- la estructura original.
create table if not exists public.pagos_fase29 (
    id uuid primary key default gen_random_uuid(),
    inscripcion_id uuid not null unique references public.inscripciones_evento(id) on delete cascade,
    evento_id uuid not null references public.eventos(id) on delete cascade,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,
    medio text not null,
    referencia text not null,
    tipo_entrada text,
    monto numeric(10,2) check (monto is null or monto >= 0),
    estado_pago text not null default 'pendiente'
        check (estado_pago in ('no_requiere', 'pendiente', 'verificado', 'rechazado')),
    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),
    check (trim(medio) <> ''),
    check (trim(referencia) <> '')
);

alter table public.pagos_fase29 enable row level security;
grant select on public.pagos_fase29 to authenticated;

drop policy if exists "pagos fase29: propio o admin lee" on public.pagos_fase29;
create policy "pagos fase29: propio o admin lee"
on public.pagos_fase29
for select
to authenticated
using (
    usuario_id = (select auth.uid())
    or (select private.usuario_tiene_rol(array['admin']::text[]))
);

-- La escritura se hace exclusivamente mediante la RPC segura de abajo.
-- No se concede INSERT/UPDATE/DELETE directo al cliente.

-- 4) Registrar referencia de pago reportada por el propio participante.
-- NO aprueba el pago. La aprobación sigue siendo exclusiva del admin
-- mediante verificar_pago_evento(...).
drop function if exists public.registrar_referencia_pago_evento(uuid, text, text);
drop function if exists public.registrar_referencia_pago_evento(uuid, text, text, text, numeric);

create or replace function public.registrar_referencia_pago_evento(
    p_evento_id uuid,
    p_medio text,
    p_referencia text,
    p_tipo_entrada text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
    v_inscripcion public.inscripciones_evento%rowtype;
    v_tarifa_nombre text;
    v_tarifa_monto numeric(10,2);
begin
    if v_uid is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if nullif(trim(coalesce(p_medio, '')), '') is null then
        raise exception 'El medio de pago es obligatorio.';
    end if;

    if nullif(trim(coalesce(p_referencia, '')), '') is null then
        raise exception 'La referencia de pago es obligatoria.';
    end if;

    select * into v_inscripcion
    from public.inscripciones_evento
    where evento_id = p_evento_id
      and usuario_id = v_uid;

    if v_inscripcion.id is null then
        raise exception 'Primero debes inscribirte al evento.';
    end if;

    if v_inscripcion.estado_pago = 'no_requiere' then
        return jsonb_build_object(
            'ok', true,
            'estado_pago', 'no_requiere',
            'mensaje', 'Este evento no requiere pago.'
        );
    end if;

    if v_inscripcion.estado_pago = 'verificado' then
        raise exception 'El pago de esta inscripción ya fue verificado.';
    end if;

    select t.nombre, t.monto
      into v_tarifa_nombre, v_tarifa_monto
    from public.tarifas_fase29 t
    where t.evento_id = p_evento_id
      and t.clave = nullif(trim(coalesce(p_tipo_entrada, '')), '')
      and t.activo = true;

    if not found then
        raise exception 'La tarifa seleccionada no existe o no está activa.';
    end if;

    -- Una referencia nueva (incluido un reintento tras rechazo) vuelve a
    -- estado pendiente para que el admin pueda evaluarla nuevamente.
    update public.inscripciones_evento
    set medio_pago = trim(p_medio),
        referencia_pago = trim(p_referencia),
        estado = 'pendiente',
        estado_pago = 'pendiente',
        pago_verificado_por = null,
        pago_verificado_en = null,
        actualizado_en = now()
    where id = v_inscripcion.id;

    insert into public.pagos_fase29 (
        inscripcion_id, evento_id, usuario_id, medio, referencia,
        tipo_entrada, monto, estado_pago, actualizado_en
    ) values (
        v_inscripcion.id, p_evento_id, v_uid, trim(p_medio), trim(p_referencia),
        v_tarifa_nombre, v_tarifa_monto, 'pendiente', now()
    )
    on conflict (inscripcion_id) do update set
        medio = excluded.medio,
        referencia = excluded.referencia,
        tipo_entrada = excluded.tipo_entrada,
        monto = excluded.monto,
        estado_pago = 'pendiente',
        actualizado_en = now();

    return jsonb_build_object(
        'ok', true,
        'estado_pago', 'pendiente',
        'tipo_entrada', v_tarifa_nombre,
        'monto', v_tarifa_monto,
        'mensaje', 'Referencia registrada. Queda pendiente de verificación administrativa.'
    );
end;
$$;

revoke execute on function public.registrar_referencia_pago_evento(uuid, text, text, text) from public, anon;
grant execute on function public.registrar_referencia_pago_evento(uuid, text, text, text) to authenticated;

-- Sincroniza el estado complementario cuando el admin usa la función original
-- verificar_pago_evento(...), sin tocar dicha función estructural.
create or replace function private.sincronizar_estado_pago_fase29()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.pagos_fase29
    set estado_pago = new.estado_pago,
        actualizado_en = now()
    where inscripcion_id = new.id;
    return new;
end;
$$;

drop trigger if exists trg_sincronizar_estado_pago_fase29 on public.inscripciones_evento;
create trigger trg_sincronizar_estado_pago_fase29
after update of estado_pago on public.inscripciones_evento
for each row
when (old.estado_pago is distinct from new.estado_pago)
execute function private.sincronizar_estado_pago_fase29();

-- 5) Eliminación voluntaria de la propia cuenta.
-- Al borrar auth.users, las FK ON DELETE CASCADE limpian el perfil y datos asociados.
create or replace function public.eliminar_mi_cuenta()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    delete from auth.users where id = v_uid;
    return true;
end;
$$;

revoke execute on function public.eliminar_mi_cuenta() from public, anon;
grant execute on function public.eliminar_mi_cuenta() to authenticated;

-- 6) Estadísticas públicas mínimas para el hero.
create or replace function public.estadisticas_publicas_evento(p_evento_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_publicado boolean;
    v_registrados bigint;
    v_talleres bigint;
begin
    select exists(
        select 1 from public.eventos e
        where e.id = p_evento_id
          and e.estado = 'publicado'
          and e.es_prueba = false
    ) into v_publicado;

    if not v_publicado then
        return jsonb_build_object('registrados', 0, 'talleres', 0);
    end if;

    select count(*) into v_registrados
    from public.inscripciones_evento ie
    where ie.evento_id = p_evento_id
      and ie.estado <> 'cancelado';

    select count(*) into v_talleres
    from public.actividades a
    where a.evento_id = p_evento_id
      and a.tipo = 'taller'
      and a.estado = 'publicado';

    return jsonb_build_object(
        'registrados', v_registrados,
        'talleres', v_talleres
    );
end;
$$;

revoke execute on function public.estadisticas_publicas_evento(uuid) from public;
grant execute on function public.estadisticas_publicas_evento(uuid) to anon, authenticated;

-- 7) Ocupación pública de talleres publicados. Devuelve solo conteos agregados,
-- nunca la identidad de los inscritos.
create or replace function public.cupos_publicos_talleres_evento(p_evento_id uuid)
returns table (actividad_id uuid, inscritos bigint)
language sql
security definer
set search_path = ''
as $$
    select a.id as actividad_id, count(ia.id)::bigint as inscritos
    from public.actividades a
    join public.eventos e on e.id = a.evento_id
    left join public.inscripciones_actividad ia
      on ia.actividad_id = a.id
     and ia.estado = 'inscrito'
    where a.evento_id = p_evento_id
      and a.tipo = 'taller'
      and a.estado = 'publicado'
      and e.estado = 'publicado'
      and e.es_prueba = false
    group by a.id;
$$;

revoke execute on function public.cupos_publicos_talleres_evento(uuid) from public;
grant execute on function public.cupos_publicos_talleres_evento(uuid) to anon, authenticated;
