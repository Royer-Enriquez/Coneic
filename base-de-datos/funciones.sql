-- ============================================================
-- BASE DE DATOS V3 - FUNCIONES
-- Archivo: funciones.sql
-- Ejecutar DESPUÉS de esquema.sql
-- ============================================================

-- ============================================================
-- 1. HELPERS PRIVADOS
-- ============================================================

create or replace function private.usuario_tiene_rol(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.perfiles p
        where p.id = (select auth.uid())
          and p.rol = any(p_roles)
          and p.activo = true
    );
$$;

create or replace function private.usuario_esta_activo()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.perfiles p
        where p.id = (select auth.uid())
          and p.activo = true
    );
$$;

create or replace function private.usuario_pertenece_equipo(p_equipo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.miembros_equipo me
        where me.equipo_id = p_equipo_id
          and me.usuario_id = (select auth.uid())
    );
$$;

-- ============================================================
-- 2. PROTEGER CAMPOS SENSIBLES DEL PERFIL
-- El correo se cambia en Auth; rol/activo solo por administrador.
-- ============================================================

create or replace function private.proteger_campos_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
begin
    -- Una petición autenticada no modifica directamente la copia del correo.
    -- El correo se sincroniza desde auth.users.
    if v_uid is not null and new.correo is distinct from old.correo then
        new.correo := old.correo;
    end if;

    if v_uid = old.id
       and not private.usuario_tiene_rol(array['admin']::text[]) then
        new.rol := old.rol;
        new.activo := old.activo;
    end if;

    return new;
end;
$$;

create trigger trg_proteger_campos_perfil
before update on public.perfiles
for each row execute function private.proteger_campos_perfil();

-- ============================================================
-- 3. INSCRIPCIÓN GENERAL AL EVENTO - IMPLEMENTACIÓN PRIVADA
-- ============================================================

create or replace function private.inscribirse_evento_impl(p_evento_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_evento public.eventos%rowtype;
    v_estado_inicial text;
    v_pago_inicial text;
    v_estado_real text;
    v_pago_real text;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select e.*
    into v_evento
    from public.eventos e
    where e.id = p_evento_id;

    if not found then
        raise exception 'El evento no existe.';
    end if;

    if v_evento.estado <> 'publicado' then
        raise exception 'El evento no está publicado.';
    end if;

    if not v_evento.inscripciones_abiertas then
        raise exception 'Las inscripciones al evento están cerradas.';
    end if;

    if v_evento.inscripcion_inicio is not null
       and now() < v_evento.inscripcion_inicio then
        raise exception 'Las inscripciones todavía no han iniciado.';
    end if;

    if v_evento.inscripcion_fin is not null
       and now() > v_evento.inscripcion_fin then
        raise exception 'El periodo de inscripción ya terminó.';
    end if;

    if v_evento.requiere_pago then
        v_estado_inicial := 'pendiente';
        v_pago_inicial := 'pendiente';
    else
        v_estado_inicial := 'inscrito';
        v_pago_inicial := 'no_requiere';
    end if;

    insert into public.inscripciones_evento (
        evento_id,
        usuario_id,
        estado,
        estado_pago
    )
    values (
        p_evento_id,
        v_usuario,
        v_estado_inicial,
        v_pago_inicial
    )
    on conflict (evento_id, usuario_id)
    do update
    set
        estado = case
            when public.inscripciones_evento.estado = 'cancelado'
                then excluded.estado
            else public.inscripciones_evento.estado
        end,
        estado_pago = case
            when public.inscripciones_evento.estado = 'cancelado'
                then excluded.estado_pago
            else public.inscripciones_evento.estado_pago
        end,
        referencia_pago = case
            when public.inscripciones_evento.estado = 'cancelado'
                then null
            else public.inscripciones_evento.referencia_pago
        end,
        pago_verificado_por = case
            when public.inscripciones_evento.estado = 'cancelado'
                then null
            else public.inscripciones_evento.pago_verificado_por
        end,
        pago_verificado_en = case
            when public.inscripciones_evento.estado = 'cancelado'
                then null
            else public.inscripciones_evento.pago_verificado_en
        end,
        actualizado_en = now()
    returning estado, estado_pago
    into v_estado_real, v_pago_real;

    return jsonb_build_object(
        'ok', true,
        'estado', v_estado_real,
        'estado_pago', v_pago_real
    );
end;
$$;

create or replace function public.inscribirse_evento(p_evento_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.inscribirse_evento_impl(p_evento_id);
$$;

-- ============================================================
-- 4. VERIFICAR PAGO EXTERNO - ADMIN
-- ============================================================

create or replace function private.verificar_pago_evento_impl(
    p_inscripcion_id uuid,
    p_aprobado boolean,
    p_referencia text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_admin uuid := auth.uid();
    v_requiere_pago boolean;
begin
    if v_admin is null
       or not private.usuario_tiene_rol(array['admin']::text[]) then
        raise exception 'No tienes permiso para verificar pagos.';
    end if;

    select e.requiere_pago
    into v_requiere_pago
    from public.inscripciones_evento ie
    join public.eventos e on e.id = ie.evento_id
    where ie.id = p_inscripcion_id;

    if not found then
        raise exception 'La inscripción no existe.';
    end if;

    if not v_requiere_pago then
        raise exception 'Este evento no requiere pago.';
    end if;

    update public.inscripciones_evento
    set
        estado_pago = case when p_aprobado then 'verificado' else 'rechazado' end,
        estado = case when p_aprobado then 'inscrito' else 'pendiente' end,
        referencia_pago = coalesce(nullif(trim(p_referencia), ''), referencia_pago),
        pago_verificado_por = v_admin,
        pago_verificado_en = now(),
        actualizado_en = now()
    where id = p_inscripcion_id;

    return jsonb_build_object(
        'ok', true,
        'aprobado', p_aprobado
    );
end;
$$;

create or replace function public.verificar_pago_evento(
    p_inscripcion_id uuid,
    p_aprobado boolean,
    p_referencia text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.verificar_pago_evento_impl(
        p_inscripcion_id,
        p_aprobado,
        p_referencia
    );
$$;

-- ============================================================
-- 5. INSCRIPCIÓN INDIVIDUAL A ACTIVIDAD
-- ============================================================

create or replace function private.inscribirse_actividad_impl(p_actividad_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_actividad public.actividades%rowtype;
    v_total integer;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select a.*
    into v_actividad
    from public.actividades a
    where a.id = p_actividad_id
    for update;

    if not found then
        raise exception 'La actividad no existe.';
    end if;

    if v_actividad.estado <> 'publicado' then
        raise exception 'La actividad no está publicada.';
    end if;

    if not v_actividad.requiere_inscripcion then
        raise exception 'Esta actividad no requiere inscripción.';
    end if;

    if not v_actividad.inscripciones_abiertas then
        raise exception 'Las inscripciones de esta actividad están cerradas.';
    end if;

    if v_actividad.inscripcion_inicio is not null
       and now() < v_actividad.inscripcion_inicio then
        raise exception 'Las inscripciones todavía no han iniciado.';
    end if;

    if v_actividad.inscripcion_fin is not null
       and now() > v_actividad.inscripcion_fin then
        raise exception 'El periodo de inscripción ya terminó.';
    end if;

    if v_actividad.modalidad_inscripcion not in ('individual', 'ambos') then
        raise exception 'Esta actividad solo admite equipos.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_actividad.evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'Debes estar inscrito correctamente al evento.';
    end if;

    -- En modalidad "ambos" no permitimos estar como individuo y equipo a la vez.
    if exists (
        select 1
        from public.miembros_equipo me
        join public.equipos eq on eq.id = me.equipo_id
        where me.actividad_id = p_actividad_id
          and me.usuario_id = v_usuario
          and eq.estado <> 'cancelado'
    ) then
        raise exception 'Ya perteneces a un equipo de esta actividad.';
    end if;

    if v_actividad.capacidad is not null then
        select count(*)
        into v_total
        from public.inscripciones_actividad ia
        where ia.actividad_id = p_actividad_id
          and ia.estado = 'inscrito';

        if v_total >= v_actividad.capacidad then
            raise exception 'No quedan cupos disponibles.';
        end if;
    end if;

    insert into public.inscripciones_actividad (
        actividad_id,
        usuario_id,
        estado
    )
    values (
        p_actividad_id,
        v_usuario,
        'inscrito'
    )
    on conflict (actividad_id, usuario_id)
    where usuario_id is not null
    do update
    set
        estado = 'inscrito',
        actualizado_en = now();

    return jsonb_build_object(
        'ok', true,
        'mensaje', 'Inscripción realizada correctamente.'
    );
end;
$$;

create or replace function public.inscribirse_actividad(p_actividad_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.inscribirse_actividad_impl(p_actividad_id);
$$;

-- ============================================================
-- 6. CREAR EQUIPO
-- ============================================================

create or replace function private.crear_equipo_impl(
    p_actividad_id uuid,
    p_nombre text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_actividad public.actividades%rowtype;
    v_equipo_id uuid;
    v_codigo uuid;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    if nullif(trim(p_nombre), '') is null then
        raise exception 'Debes indicar un nombre para el equipo.';
    end if;

    select a.*
    into v_actividad
    from public.actividades a
    where a.id = p_actividad_id;

    if not found then
        raise exception 'La actividad no existe.';
    end if;

    if v_actividad.estado <> 'publicado'
       or not v_actividad.requiere_inscripcion
       or not v_actividad.inscripciones_abiertas then
        raise exception 'La actividad no admite nuevas inscripciones.';
    end if;

    if v_actividad.inscripcion_inicio is not null
       and now() < v_actividad.inscripcion_inicio then
        raise exception 'Las inscripciones todavía no han iniciado.';
    end if;

    if v_actividad.inscripcion_fin is not null
       and now() > v_actividad.inscripcion_fin then
        raise exception 'El periodo de inscripción ya terminó.';
    end if;

    if v_actividad.modalidad_inscripcion not in ('equipo', 'ambos') then
        raise exception 'Esta actividad no permite inscripción por equipos.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_actividad.evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'Debes estar inscrito correctamente al evento.';
    end if;

    if exists (
        select 1
        from public.inscripciones_actividad ia
        where ia.actividad_id = p_actividad_id
          and ia.usuario_id = v_usuario
          and ia.estado <> 'cancelado'
    ) then
        raise exception 'Ya tienes una inscripción individual en esta actividad.';
    end if;

    -- La restricción UNIQUE (actividad_id, usuario_id) en miembros_equipo
    -- también protege contra carreras/concurrencia.
    if exists (
        select 1
        from public.miembros_equipo me
        where me.actividad_id = p_actividad_id
          and me.usuario_id = v_usuario
    ) then
        raise exception 'Ya perteneces a un equipo de esta actividad.';
    end if;

    insert into public.equipos (
        actividad_id,
        nombre,
        lider_usuario_id
    )
    values (
        p_actividad_id,
        trim(p_nombre),
        v_usuario
    )
    returning id, codigo_invitacion
    into v_equipo_id, v_codigo;

    insert into public.miembros_equipo (
        equipo_id,
        actividad_id,
        usuario_id,
        rol_equipo
    )
    values (
        v_equipo_id,
        p_actividad_id,
        v_usuario,
        'lider'
    );

    return jsonb_build_object(
        'ok', true,
        'equipo_id', v_equipo_id,
        'codigo_invitacion', v_codigo
    );
end;
$$;

create or replace function public.crear_equipo(
    p_actividad_id uuid,
    p_nombre text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.crear_equipo_impl(p_actividad_id, p_nombre);
$$;

-- ============================================================
-- 7. UNIRSE A EQUIPO
-- El bloqueo FOR UPDATE evita superar el máximo por concurrencia.
-- ============================================================

create or replace function private.unirse_equipo_impl(p_codigo_invitacion uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_equipo public.equipos%rowtype;
    v_actividad public.actividades%rowtype;
    v_total integer;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select eq.*
    into v_equipo
    from public.equipos eq
    where eq.codigo_invitacion = p_codigo_invitacion
    for update;

    if not found then
        raise exception 'El código del equipo no es válido.';
    end if;

    if v_equipo.estado <> 'formando' then
        raise exception 'El equipo ya no acepta nuevos integrantes.';
    end if;

    select a.*
    into v_actividad
    from public.actividades a
    where a.id = v_equipo.actividad_id;

    if not found
       or v_actividad.estado <> 'publicado'
       or not v_actividad.inscripciones_abiertas then
        raise exception 'La actividad no admite nuevas inscripciones.';
    end if;

    if v_actividad.inscripcion_inicio is not null
       and now() < v_actividad.inscripcion_inicio then
        raise exception 'Las inscripciones todavía no han iniciado.';
    end if;

    if v_actividad.inscripcion_fin is not null
       and now() > v_actividad.inscripcion_fin then
        raise exception 'El periodo de inscripción ya terminó.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_actividad.evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'Debes estar inscrito correctamente al evento.';
    end if;

    if exists (
        select 1
        from public.inscripciones_actividad ia
        where ia.actividad_id = v_actividad.id
          and ia.usuario_id = v_usuario
          and ia.estado <> 'cancelado'
    ) then
        raise exception 'Ya tienes una inscripción individual en esta actividad.';
    end if;

    if exists (
        select 1
        from public.miembros_equipo me
        where me.actividad_id = v_actividad.id
          and me.usuario_id = v_usuario
    ) then
        raise exception 'Ya perteneces a un equipo de esta actividad.';
    end if;

    select count(*)
    into v_total
    from public.miembros_equipo me
    where me.equipo_id = v_equipo.id;

    if v_total >= v_actividad.maximo_integrantes_equipo then
        raise exception 'El equipo ya alcanzó el máximo de integrantes.';
    end if;

    insert into public.miembros_equipo (
        equipo_id,
        actividad_id,
        usuario_id,
        rol_equipo
    )
    values (
        v_equipo.id,
        v_actividad.id,
        v_usuario,
        'miembro'
    );

    return jsonb_build_object(
        'ok', true,
        'equipo_id', v_equipo.id,
        'mensaje', 'Te uniste al equipo correctamente.'
    );
end;
$$;

create or replace function public.unirse_equipo(p_codigo_invitacion uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.unirse_equipo_impl(p_codigo_invitacion);
$$;

-- ============================================================
-- 8. INSCRIBIR EQUIPO A ACTIVIDAD
-- ============================================================

create or replace function private.inscribir_equipo_actividad_impl(p_equipo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_equipo public.equipos%rowtype;
    v_actividad public.actividades%rowtype;
    v_integrantes integer;
    v_total_inscripciones integer;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select eq.*
    into v_equipo
    from public.equipos eq
    where eq.id = p_equipo_id
    for update;

    if not found then
        raise exception 'El equipo no existe.';
    end if;

    if v_equipo.lider_usuario_id <> v_usuario then
        raise exception 'Solo el líder puede inscribir al equipo.';
    end if;

    if v_equipo.estado = 'cancelado' then
        raise exception 'El equipo está cancelado.';
    end if;

    if v_equipo.estado = 'inscrito' then
        return jsonb_build_object(
            'ok', true,
            'mensaje', 'El equipo ya estaba inscrito.'
        );
    end if;

    select a.*
    into v_actividad
    from public.actividades a
    where a.id = v_equipo.actividad_id
    for update;

    if not found
       or v_actividad.estado <> 'publicado'
       or not v_actividad.inscripciones_abiertas then
        raise exception 'La actividad no admite nuevas inscripciones.';
    end if;

    if v_actividad.modalidad_inscripcion not in ('equipo', 'ambos') then
        raise exception 'La actividad no admite inscripción por equipo.';
    end if;

    if v_actividad.inscripcion_inicio is not null
       and now() < v_actividad.inscripcion_inicio then
        raise exception 'Las inscripciones todavía no han iniciado.';
    end if;

    if v_actividad.inscripcion_fin is not null
       and now() > v_actividad.inscripcion_fin then
        raise exception 'El periodo de inscripción ya terminó.';
    end if;

    select count(*)
    into v_integrantes
    from public.miembros_equipo me
    where me.equipo_id = p_equipo_id;

    if v_integrantes < v_actividad.minimo_integrantes_equipo then
        raise exception 'El equipo todavía no cumple el mínimo de integrantes.';
    end if;

    if v_integrantes > v_actividad.maximo_integrantes_equipo then
        raise exception 'El equipo supera el máximo de integrantes.';
    end if;

    -- Todos los integrantes deben seguir inscritos correctamente al evento.
    if exists (
        select 1
        from public.miembros_equipo me
        where me.equipo_id = p_equipo_id
          and not exists (
              select 1
              from public.inscripciones_evento ie
              where ie.evento_id = v_actividad.evento_id
                and ie.usuario_id = me.usuario_id
                and ie.estado = 'inscrito'
          )
    ) then
        raise exception 'Uno o más integrantes no tienen una inscripción válida al evento.';
    end if;

    -- Ningún integrante puede estar simultáneamente inscrito como individuo.
    if exists (
        select 1
        from public.miembros_equipo me
        join public.inscripciones_actividad ia
          on ia.actividad_id = v_actividad.id
         and ia.usuario_id = me.usuario_id
        where me.equipo_id = p_equipo_id
          and ia.estado <> 'cancelado'
    ) then
        raise exception 'Un integrante ya está inscrito individualmente en esta actividad.';
    end if;

    if v_actividad.capacidad is not null then
        select count(*)
        into v_total_inscripciones
        from public.inscripciones_actividad ia
        where ia.actividad_id = v_actividad.id
          and ia.estado = 'inscrito';

        if v_total_inscripciones >= v_actividad.capacidad then
            raise exception 'No quedan cupos disponibles.';
        end if;
    end if;

    insert into public.inscripciones_actividad (
        actividad_id,
        equipo_id,
        estado
    )
    values (
        v_actividad.id,
        p_equipo_id,
        'inscrito'
    )
    on conflict (actividad_id, equipo_id)
    where equipo_id is not null
    do update
    set
        estado = 'inscrito',
        actualizado_en = now();

    update public.equipos
    set estado = 'inscrito'
    where id = p_equipo_id;

    return jsonb_build_object(
        'ok', true,
        'mensaje', 'Equipo inscrito correctamente.'
    );
end;
$$;

create or replace function public.inscribir_equipo_actividad(p_equipo_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.inscribir_equipo_actividad_impl(p_equipo_id);
$$;

-- ============================================================
-- 9. OBTENER O CREAR QR
-- Corrige el problema de un QR previamente desactivado:
-- se reactiva y rota el token en vez de intentar insertar un duplicado.
-- ============================================================

create or replace function private.obtener_o_crear_qr_impl(p_evento_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_token uuid;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        join public.eventos e on e.id = ie.evento_id
        where ie.evento_id = p_evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
          and e.estado = 'publicado'
    ) then
        raise exception 'Tu inscripción al evento todavía no está habilitada.';
    end if;

    insert into public.credenciales_qr (
        evento_id,
        usuario_id,
        token,
        activo
    )
    values (
        p_evento_id,
        v_usuario,
        gen_random_uuid(),
        true
    )
    on conflict (evento_id, usuario_id)
    do update
    set
        token = case
            when public.credenciales_qr.activo
                then public.credenciales_qr.token
            else gen_random_uuid()
        end,
        activo = true,
        actualizado_en = now()
    returning token into v_token;

    return v_token;
end;
$$;

create or replace function public.obtener_o_crear_qr(p_evento_id uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $$
    select private.obtener_o_crear_qr_impl(p_evento_id);
$$;

-- Permite invalidar una captura antigua del QR y generar otro token.
create or replace function private.regenerar_qr_impl(p_evento_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_token uuid;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        join public.eventos e on e.id = ie.evento_id
        where ie.evento_id = p_evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
          and e.estado = 'publicado'
    ) then
        raise exception 'Tu inscripción al evento no está habilitada.';
    end if;

    insert into public.credenciales_qr (
        evento_id,
        usuario_id,
        token,
        activo
    )
    values (
        p_evento_id,
        v_usuario,
        gen_random_uuid(),
        true
    )
    on conflict (evento_id, usuario_id)
    do update
    set
        token = gen_random_uuid(),
        activo = true,
        actualizado_en = now()
    returning token into v_token;

    return v_token;
end;
$$;

create or replace function public.regenerar_qr(p_evento_id uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $$
    select private.regenerar_qr_impl(p_evento_id);
$$;

-- ============================================================
-- 10. CURSOS DEL USUARIO
-- El usuario puede asociarse a cualquier curso activo de su evento.
-- No se valida relación temática entre curso y ponencia.
-- ============================================================

create or replace function private.agregar_mi_curso_impl(p_curso_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_curso public.cursos%rowtype;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select c.*
    into v_curso
    from public.cursos c
    where c.id = p_curso_id
      and c.activo = true;

    if not found then
        raise exception 'El curso no existe o no está activo.';
    end if;

    if not v_curso.permite_autoinscripcion then
        raise exception 'Este curso requiere asignación administrativa.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_curso.evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'Debes estar inscrito correctamente al evento.';
    end if;

    insert into public.curso_participantes (
        curso_id,
        usuario_id,
        estado,
        origen
    )
    values (
        p_curso_id,
        v_usuario,
        'activo',
        'usuario'
    )
    on conflict (curso_id, usuario_id)
    do update
    set
        estado = 'activo',
        actualizado_en = now();

    return jsonb_build_object(
        'ok', true,
        'mensaje', 'Curso agregado correctamente.'
    );
end;
$$;

create or replace function public.agregar_mi_curso(p_curso_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.agregar_mi_curso_impl(p_curso_id);
$$;

-- ============================================================
-- 11. ELEGIR CURSO PARA UNA PONENCIA / ACTIVIDAD
-- Una actividad puede asignarse a uno o varios cursos del usuario.
-- NO existe una lista de cursos "permitidos" por tema.
-- ============================================================

create or replace function private.seleccionar_curso_asistencia_impl(
    p_actividad_id uuid,
    p_curso_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_evento_actividad uuid;
    v_evento_curso uuid;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    select a.evento_id
    into v_evento_actividad
    from public.actividades a
    where a.id = p_actividad_id
      and a.estado = 'publicado'
      and a.controla_asistencia = true;

    if not found then
        raise exception 'La actividad no está habilitada para control de asistencia.';
    end if;

    select c.evento_id
    into v_evento_curso
    from public.cursos c
    join public.curso_participantes cp
      on cp.curso_id = c.id
     and cp.usuario_id = v_usuario
     and cp.estado = 'activo'
    where c.id = p_curso_id
      and c.activo = true;

    if not found then
        raise exception 'Ese curso no forma parte de tus cursos activos.';
    end if;

    if v_evento_actividad <> v_evento_curso then
        raise exception 'El curso y la actividad pertenecen a eventos diferentes.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_evento_actividad
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'Debes estar inscrito correctamente al evento.';
    end if;

    insert into public.asignaciones_asistencia_curso (
        evento_id,
        actividad_id,
        curso_id,
        usuario_id,
        estado
    )
    values (
        v_evento_actividad,
        p_actividad_id,
        p_curso_id,
        v_usuario,
        'seleccionado'
    )
    on conflict (usuario_id, actividad_id, curso_id)
    do update
    set
        estado = 'seleccionado',
        seleccionado_en = now(),
        actualizado_en = now();

    return jsonb_build_object(
        'ok', true,
        'mensaje', 'La actividad quedó asociada al curso seleccionado.'
    );
end;
$$;

create or replace function public.seleccionar_curso_asistencia(
    p_actividad_id uuid,
    p_curso_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.seleccionar_curso_asistencia_impl(
        p_actividad_id,
        p_curso_id
    );
$$;

create or replace function private.quitar_curso_asistencia_impl(
    p_actividad_id uuid,
    p_curso_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    update public.asignaciones_asistencia_curso
    set
        estado = 'retirado',
        actualizado_en = now()
    where actividad_id = p_actividad_id
      and curso_id = p_curso_id
      and usuario_id = v_usuario;

    if not found then
        raise exception 'No existe esa asignación de curso.';
    end if;

    return jsonb_build_object(
        'ok', true,
        'mensaje', 'La actividad dejó de contar para ese curso.'
    );
end;
$$;

create or replace function public.quitar_curso_asistencia(
    p_actividad_id uuid,
    p_curso_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.quitar_curso_asistencia_impl(
        p_actividad_id,
        p_curso_id
    );
$$;

-- ============================================================
-- 12. ESCANEO QR POR SALA
-- - sin sesión abierta -> ENTRADA
-- - misma sala abierta -> SALIDA
-- - otra sala abierta -> CAMBIO DE SALA
-- - permite nuevas entradas después de haber salido (almuerzo, pausas, etc.)
-- ============================================================

create or replace function private.registrar_escaneo_sala_impl(
    p_token uuid,
    p_sala_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_operador uuid := auth.uid();
    v_usuario uuid;
    v_evento_qr uuid;
    v_sala public.salas%rowtype;
    v_sesion public.sesiones_presencia%rowtype;
    v_participante text;
    v_sala_anterior text;
    v_momento timestamptz := now();
    v_nueva_sesion_id uuid;
begin
    if v_operador is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_tiene_rol(array['admin', 'control']::text[]) then
        raise exception 'No tienes permiso para registrar presencia.';
    end if;

    select q.usuario_id, q.evento_id
    into v_usuario, v_evento_qr
    from public.credenciales_qr q
    where q.token = p_token
      and q.activo = true;

    if v_usuario is null then
        raise exception 'QR inválido o desactivado.';
    end if;

    select s.*
    into v_sala
    from public.salas s
    where s.id = p_sala_id
      and s.activo = true;

    if not found then
        raise exception 'La sala no existe o no está activa.';
    end if;

    if v_sala.evento_id <> v_evento_qr then
        raise exception 'El QR no corresponde al evento de esta sala.';
    end if;

    if not exists (
        select 1
        from public.perfiles p
        where p.id = v_usuario
          and p.activo = true
    ) then
        raise exception 'La cuenta del participante está desactivada.';
    end if;

    if not exists (
        select 1
        from public.eventos e
        where e.id = v_sala.evento_id
          and e.estado = 'publicado'
    ) then
        raise exception 'El evento no está habilitado para registrar presencia.';
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = v_sala.evento_id
          and ie.usuario_id = v_usuario
          and ie.estado = 'inscrito'
    ) then
        raise exception 'El participante no tiene una inscripción válida al evento.';
    end if;

    select trim(p.nombres || ' ' || p.apellidos)
    into v_participante
    from public.perfiles p
    where p.id = v_usuario;

    -- Un solo flujo de entrada/salida por usuario a la vez.
    perform pg_advisory_xact_lock(
        hashtext(v_usuario::text)
    );

    select sp.*
    into v_sesion
    from public.sesiones_presencia sp
    where sp.usuario_id = v_usuario
      and sp.salida_en is null
      and sp.estado <> 'anulada'
    for update;

    -- No hay sesión abierta: nueva entrada.
    if not found then
        insert into public.sesiones_presencia (
            evento_id,
            sala_id,
            usuario_id,
            entrada_en,
            entrada_registrada_por,
            estado
        )
        values (
            v_sala.evento_id,
            v_sala.id,
            v_usuario,
            v_momento,
            v_operador,
            'registrada'
        )
        returning id into v_nueva_sesion_id;

        return jsonb_build_object(
            'ok', true,
            'accion', 'entrada',
            'sala', v_sala.nombre,
            'participante', v_participante,
            'sesion_id', v_nueva_sesion_id,
            'momento', v_momento
        );
    end if;

    -- Misma sala: segundo escaneo válido = salida.
    if v_sesion.sala_id = v_sala.id then
        if v_momento - v_sesion.entrada_en < interval '30 seconds' then
            raise exception 'Escaneo duplicado. Espera unos segundos antes de volver a escanear.';
        end if;

        update public.sesiones_presencia
        set
            salida_en = v_momento,
            salida_registrada_por = v_operador,
            actualizado_en = v_momento
        where id = v_sesion.id;

        return jsonb_build_object(
            'ok', true,
            'accion', 'salida',
            'sala', v_sala.nombre,
            'participante', v_participante,
            'sesion_id', v_sesion.id,
            'momento', v_momento
        );
    end if;

    -- Escaneo en otra sala: cierra la anterior y abre la nueva.
    select s.nombre
    into v_sala_anterior
    from public.salas s
    where s.id = v_sesion.sala_id;

    update public.sesiones_presencia
    set
        salida_en = v_momento,
        salida_registrada_por = v_operador,
        actualizado_en = v_momento
    where id = v_sesion.id;

    insert into public.sesiones_presencia (
        evento_id,
        sala_id,
        usuario_id,
        entrada_en,
        entrada_registrada_por,
        estado
    )
    values (
        v_sala.evento_id,
        v_sala.id,
        v_usuario,
        v_momento,
        v_operador,
        'registrada'
    )
    returning id into v_nueva_sesion_id;

    return jsonb_build_object(
        'ok', true,
        'accion', 'cambio_sala',
        'sala_anterior', v_sala_anterior,
        'sala_nueva', v_sala.nombre,
        'participante', v_participante,
        'sesion_id', v_nueva_sesion_id,
        'momento', v_momento
    );
end;
$$;

create or replace function public.registrar_escaneo_sala(
    p_token uuid,
    p_sala_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.registrar_escaneo_sala_impl(
        p_token,
        p_sala_id
    );
$$;

-- ============================================================
-- 13. CÁLCULO DE PRESENCIA EN UNA ACTIVIDAD
-- Cruza los horarios de la actividad con todas las sesiones de la sala.
-- ============================================================

create or replace function private.calcular_presencia_actividad_impl(
    p_usuario_id uuid,
    p_actividad_id uuid
)
returns table (
    primera_entrada timestamptz,
    ultima_salida timestamptz,
    minutos_presentes numeric,
    duracion_actividad_minutos numeric,
    porcentaje_presencia numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actividad public.actividades%rowtype;
    v_minutos numeric := 0;
    v_duracion numeric := 0;
    v_primera timestamptz;
    v_ultima timestamptz;
begin
    select a.*
    into v_actividad
    from public.actividades a
    where a.id = p_actividad_id
      and a.controla_asistencia = true
      and a.sala_id is not null
      and a.fecha_inicio is not null
      and a.fecha_fin is not null;

    if not found then
        return query
        select null::timestamptz,
               null::timestamptz,
               0::numeric,
               0::numeric,
               0::numeric;
        return;
    end if;

    v_duracion :=
        extract(epoch from (v_actividad.fecha_fin - v_actividad.fecha_inicio)) / 60.0;

    select
        min(greatest(sp.entrada_en, v_actividad.fecha_inicio)),
        max(
            least(
                coalesce(sp.salida_en, least(now(), v_actividad.fecha_fin)),
                v_actividad.fecha_fin
            )
        ),
        coalesce(
            sum(
                extract(
                    epoch from (
                        least(
                            coalesce(sp.salida_en, least(now(), v_actividad.fecha_fin)),
                            v_actividad.fecha_fin
                        )
                        -
                        greatest(sp.entrada_en, v_actividad.fecha_inicio)
                    )
                ) / 60.0
            ),
            0
        )
    into
        v_primera,
        v_ultima,
        v_minutos
    from public.sesiones_presencia sp
    where sp.usuario_id = p_usuario_id
      and sp.evento_id = v_actividad.evento_id
      and sp.sala_id = v_actividad.sala_id
      and sp.estado <> 'anulada'
      and sp.entrada_en < v_actividad.fecha_fin
      and coalesce(sp.salida_en, now()) > v_actividad.fecha_inicio;

    return query
    select
        v_primera,
        v_ultima,
        round(v_minutos, 2),
        round(v_duracion, 2),
        case
            when v_duracion <= 0 then 0::numeric
            else round(least(100::numeric, (v_minutos / v_duracion) * 100), 2)
        end;
end;
$$;

-- ============================================================
-- 14. MI ASISTENCIA
-- Permite al participante consultar su propia permanencia.
-- ============================================================

create or replace function private.mi_asistencia_evento_impl(p_evento_id uuid)
returns table (
    actividad_id uuid,
    actividad text,
    sala text,
    fecha_inicio timestamptz,
    fecha_fin timestamptz,
    primera_entrada timestamptz,
    ultima_salida timestamptz,
    minutos_presentes numeric,
    porcentaje_presencia numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    return query
    select
        a.id,
        a.titulo,
        s.nombre,
        a.fecha_inicio,
        a.fecha_fin,
        calc.primera_entrada,
        calc.ultima_salida,
        calc.minutos_presentes,
        calc.porcentaje_presencia
    from public.actividades a
    join public.salas s on s.id = a.sala_id
    cross join lateral private.calcular_presencia_actividad_impl(
        v_usuario,
        a.id
    ) calc
    where a.evento_id = p_evento_id
      and a.controla_asistencia = true
      and a.estado in ('publicado', 'finalizado')
    order by a.fecha_inicio;
end;
$$;

create or replace function public.mi_asistencia_evento(p_evento_id uuid)
returns table (
    actividad_id uuid,
    actividad text,
    sala text,
    fecha_inicio timestamptz,
    fecha_fin timestamptz,
    primera_entrada timestamptz,
    ultima_salida timestamptz,
    minutos_presentes numeric,
    porcentaje_presencia numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
    select *
    from private.mi_asistencia_evento_impl(p_evento_id);
$$;

-- ============================================================
-- 15. REPORTE DE ASISTENCIA POR CURSO Y PONENCIA
-- Incluye a TODOS los alumnos del curso.
-- El usuario elige libremente si esa ponencia cuenta para ese curso.
-- ============================================================

create or replace function private.reporte_asistencia_curso_impl(
    p_curso_id uuid,
    p_actividad_id uuid
)
returns table (
    usuario_id uuid,
    correo text,
    participante text,
    curso text,
    docente text,
    actividad text,
    seleccionado_para_curso boolean,
    seleccionado_en timestamptz,
    primera_entrada timestamptz,
    ultima_salida timestamptz,
    minutos_presentes numeric,
    porcentaje_presencia numeric,
    estado_academico text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_admin uuid := auth.uid();
    v_curso public.cursos%rowtype;
    v_actividad public.actividades%rowtype;
begin
    if v_admin is null
       or not private.usuario_tiene_rol(array['admin']::text[]) then
        raise exception 'No tienes permiso para generar reportes académicos.';
    end if;

    select c.*
    into v_curso
    from public.cursos c
    where c.id = p_curso_id;

    if not found then
        raise exception 'El curso no existe.';
    end if;

    select a.*
    into v_actividad
    from public.actividades a
    where a.id = p_actividad_id
      and a.controla_asistencia = true;

    if not found then
        raise exception 'La actividad no permite calcular asistencia.';
    end if;

    if v_curso.evento_id <> v_actividad.evento_id then
        raise exception 'El curso y la actividad pertenecen a eventos diferentes.';
    end if;

    return query
    select
        p.id,
        p.correo,
        trim(p.nombres || ' ' || p.apellidos),
        v_curso.nombre,
        v_curso.docente,
        v_actividad.titulo,
        (aac.id is not null and aac.estado = 'seleccionado') as seleccionado_para_curso,
        case
            when aac.estado = 'seleccionado' then aac.seleccionado_en
            else null
        end,
        calc.primera_entrada,
        calc.ultima_salida,
        calc.minutos_presentes,
        calc.porcentaje_presencia,
        case
            when aac.id is null or aac.estado <> 'seleccionado'
                then 'NO_REGISTRADO'
            when calc.porcentaje_presencia >= v_curso.porcentaje_minimo_asistencia
                then 'ASISTIO'
            when calc.porcentaje_presencia > 0
                then 'ASISTENCIA_PARCIAL'
            else 'NO_ASISTIO'
        end
    from public.curso_participantes cp
    join public.perfiles p
      on p.id = cp.usuario_id
    left join public.asignaciones_asistencia_curso aac
      on aac.curso_id = cp.curso_id
     and aac.usuario_id = cp.usuario_id
     and aac.actividad_id = p_actividad_id
    cross join lateral private.calcular_presencia_actividad_impl(
        cp.usuario_id,
        p_actividad_id
    ) calc
    where cp.curso_id = p_curso_id
      and cp.estado = 'activo'
      and p.activo = true
    order by p.apellidos, p.nombres, p.correo;
end;
$$;

create or replace function public.reporte_asistencia_curso(
    p_curso_id uuid,
    p_actividad_id uuid
)
returns table (
    usuario_id uuid,
    correo text,
    participante text,
    curso text,
    docente text,
    actividad text,
    seleccionado_para_curso boolean,
    seleccionado_en timestamptz,
    primera_entrada timestamptz,
    ultima_salida timestamptz,
    minutos_presentes numeric,
    porcentaje_presencia numeric,
    estado_academico text
)
language sql
stable
security invoker
set search_path = ''
as $$
    select *
    from private.reporte_asistencia_curso_impl(
        p_curso_id,
        p_actividad_id
    );
$$;


-- ============================================================
-- 11. ELEGIBILIDAD AUTOMÁTICA PARA CERTIFICADO
-- El porcentaje se calcula ponderando por duración:
--
--   minutos presentes en actividades certificables
--   ------------------------------------------------ x 100
--   minutos programados de actividades certificables
--
-- Solo cuentan actividades con:
--   cuenta_para_certificado = true
--   controla_asistencia = true
--   horario y sala válidos
--
-- Para emitir automáticamente, TODAS las actividades certificables
-- deben haber terminado.
-- ============================================================

create or replace function private.calcular_elegibilidad_certificado_impl(
    p_usuario_id uuid,
    p_evento_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_evento public.eventos%rowtype;
    v_perfil public.perfiles%rowtype;

    v_actividades integer := 0;
    v_actividades_pendientes integer := 0;

    v_minutos_programados numeric := 0;
    v_minutos_presentes numeric := 0;
    v_porcentaje numeric := 0;

    v_codigo_existente text;
    v_apto boolean := false;
    v_motivo text;
begin
    select e.*
    into v_evento
    from public.eventos e
    where e.id = p_evento_id;

    if not found then
        raise exception 'El evento no existe.';
    end if;

    select p.*
    into v_perfil
    from public.perfiles p
    where p.id = p_usuario_id;

    if not found then
        raise exception 'El participante no existe.';
    end if;

    if not v_perfil.activo then
        return jsonb_build_object(
            'apto', false,
            'ya_emitido', false,
            'codigo_existente', null,
            'porcentaje_obtenido', 0,
            'porcentaje_requerido', v_evento.porcentaje_minimo_certificado,
            'minutos_presentes', 0,
            'minutos_programados', 0,
            'actividades_consideradas', 0,
            'actividades_pendientes', 0,
            'motivo', 'Tu cuenta está desactivada.'
        );
    end if;

    if v_evento.estado not in ('publicado', 'finalizado') then
        return jsonb_build_object(
            'apto', false,
            'ya_emitido', false,
            'codigo_existente', null,
            'porcentaje_obtenido', 0,
            'porcentaje_requerido', v_evento.porcentaje_minimo_certificado,
            'minutos_presentes', 0,
            'minutos_programados', 0,
            'actividades_consideradas', 0,
            'actividades_pendientes', 0,
            'motivo',
                case
                    when v_evento.estado = 'cancelado'
                        then 'El evento está cancelado.'
                    else 'El evento todavía no está habilitado para certificados.'
                end
        );
    end if;

    if not exists (
        select 1
        from public.inscripciones_evento ie
        where ie.evento_id = p_evento_id
          and ie.usuario_id = p_usuario_id
          and ie.estado = 'inscrito'
    ) then
        return jsonb_build_object(
            'apto', false,
            'ya_emitido', false,
            'codigo_existente', null,
            'porcentaje_obtenido', 0,
            'porcentaje_requerido', v_evento.porcentaje_minimo_certificado,
            'minutos_presentes', 0,
            'minutos_programados', 0,
            'actividades_consideradas', 0,
            'actividades_pendientes', 0,
            'motivo', 'No tienes una inscripción válida al evento.'
        );
    end if;

    -- Si ya existe, se considera resuelto aunque posteriormente cambie
    -- el porcentaje mínimo del evento.
    select c.codigo
    into v_codigo_existente
    from public.certificados c
    where c.evento_id = p_evento_id
      and c.usuario_id = p_usuario_id
      and c.actividad_id is null
      and c.tipo = 'participacion'
      and c.estado = 'emitido'
    limit 1;

    select
        count(*)::integer,
        count(*) filter (
            where a.fecha_fin > now()
        )::integer,
        coalesce(
            sum(
                extract(epoch from (a.fecha_fin - a.fecha_inicio)) / 60.0
            ),
            0
        ),
        coalesce(
            sum(calc.minutos_presentes),
            0
        )
    into
        v_actividades,
        v_actividades_pendientes,
        v_minutos_programados,
        v_minutos_presentes
    from public.actividades a
    cross join lateral private.calcular_presencia_actividad_impl(
        p_usuario_id,
        a.id
    ) calc
    where a.evento_id = p_evento_id
      and a.cuenta_para_certificado = true
      and a.controla_asistencia = true
      and a.estado in ('publicado', 'finalizado')
      and a.sala_id is not null
      and a.fecha_inicio is not null
      and a.fecha_fin is not null
      and a.fecha_fin > a.fecha_inicio;

    if v_minutos_programados > 0 then
        v_porcentaje :=
            round(
                least(
                    100::numeric,
                    (v_minutos_presentes / v_minutos_programados) * 100
                ),
                2
            );
    else
        v_porcentaje := 0;
    end if;

    if v_codigo_existente is not null then
        return jsonb_build_object(
            'apto', true,
            'ya_emitido', true,
            'codigo_existente', v_codigo_existente,
            'porcentaje_obtenido', v_porcentaje,
            'porcentaje_requerido', v_evento.porcentaje_minimo_certificado,
            'minutos_presentes', round(v_minutos_presentes, 2),
            'minutos_programados', round(v_minutos_programados, 2),
            'actividades_consideradas', v_actividades,
            'actividades_pendientes', v_actividades_pendientes,
            'motivo', 'Tu certificado ya está emitido.'
        );
    end if;

    if nullif(
        trim(
            coalesce(v_perfil.nombres, '') || ' ' ||
            coalesce(v_perfil.apellidos, '')
        ),
        ''
    ) is null then
        v_motivo :=
            'Debes completar tus nombres y apellidos antes de generar el certificado.';

    elsif v_actividades = 0 then
        v_motivo :=
            'El evento todavía no tiene actividades configuradas para el certificado.';

    elsif v_actividades_pendientes > 0 then
        v_motivo :=
            'Aún hay actividades que cuentan para el certificado y no han terminado.';

    elsif v_porcentaje >= v_evento.porcentaje_minimo_certificado then
        v_apto := true;
        v_motivo :=
            'Cumples el porcentaje mínimo de asistencia para generar tu certificado.';

    else
        v_motivo :=
            'Todavía no alcanzas el porcentaje mínimo de asistencia requerido.';
    end if;

    return jsonb_build_object(
        'apto', v_apto,
        'ya_emitido', false,
        'codigo_existente', null,
        'porcentaje_obtenido', v_porcentaje,
        'porcentaje_requerido', v_evento.porcentaje_minimo_certificado,
        'minutos_presentes', round(v_minutos_presentes, 2),
        'minutos_programados', round(v_minutos_programados, 2),
        'actividades_consideradas', v_actividades,
        'actividades_pendientes', v_actividades_pendientes,
        'motivo', v_motivo
    );
end;
$$;


create or replace function private.mi_elegibilidad_certificado_impl(
    p_evento_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    return private.calcular_elegibilidad_certificado_impl(
        v_usuario,
        p_evento_id
    );
end;
$$;


create or replace function public.mi_elegibilidad_certificado(
    p_evento_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
    select private.mi_elegibilidad_certificado_impl(p_evento_id);
$$;


-- ============================================================
-- 12. AUTOEMISIÓN DE CERTIFICADO POR EL PARTICIPANTE
-- El usuario SOLO puede emitir su propio certificado de participación.
-- No se abre INSERT directo sobre public.certificados.
-- ============================================================

create or replace function private.emitir_mi_certificado_impl(
    p_evento_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_usuario uuid := auth.uid();
    v_elegibilidad jsonb;

    v_nombre_participante text;
    v_nombre_evento text;

    v_codigo text;
    v_porcentaje numeric;
    v_requerido numeric;
begin
    if v_usuario is null then
        raise exception 'Debes iniciar sesión.';
    end if;

    if not private.usuario_esta_activo() then
        raise exception 'Tu cuenta está desactivada.';
    end if;

    v_elegibilidad :=
        private.calcular_elegibilidad_certificado_impl(
            v_usuario,
            p_evento_id
        );

    if coalesce((v_elegibilidad ->> 'ya_emitido')::boolean, false) then
        return jsonb_build_object(
            'ok', true,
            'codigo', v_elegibilidad ->> 'codigo_existente',
            'porcentaje_asistencia',
                (v_elegibilidad ->> 'porcentaje_obtenido')::numeric,
            'porcentaje_requerido',
                (v_elegibilidad ->> 'porcentaje_requerido')::numeric,
            'mensaje', 'Tu certificado ya estaba generado.'
        );
    end if;

    if not coalesce((v_elegibilidad ->> 'apto')::boolean, false) then
        raise exception '%',
            coalesce(
                v_elegibilidad ->> 'motivo',
                'Todavía no cumples los requisitos para generar tu certificado.'
            );
    end if;

    select trim(
        coalesce(p.nombres, '') || ' ' ||
        coalesce(p.apellidos, '')
    )
    into v_nombre_participante
    from public.perfiles p
    where p.id = v_usuario;

    if nullif(trim(v_nombre_participante), '') is null then
        raise exception
            'Debes completar tus nombres y apellidos antes de generar el certificado.';
    end if;

    select e.nombre
    into v_nombre_evento
    from public.eventos e
    where e.id = p_evento_id;

    if not found then
        raise exception 'El evento no existe.';
    end if;

    v_porcentaje :=
        (v_elegibilidad ->> 'porcentaje_obtenido')::numeric;

    v_requerido :=
        (v_elegibilidad ->> 'porcentaje_requerido')::numeric;

    insert into public.certificados (
        evento_id,
        actividad_id,
        usuario_id,
        tipo,
        origen_emision,
        porcentaje_asistencia,
        porcentaje_requerido,
        nombre_participante,
        nombre_evento,
        nombre_actividad,
        pdf_url,
        emitido_por
    )
    values (
        p_evento_id,
        null,
        v_usuario,
        'participacion',
        'automatico_usuario',
        v_porcentaje,
        v_requerido,
        v_nombre_participante,
        v_nombre_evento,
        null,
        null,
        v_usuario
    )
    on conflict do nothing
    returning codigo into v_codigo;

    -- Protección adicional ante dos clics concurrentes.
    if v_codigo is null then
        select c.codigo
        into v_codigo
        from public.certificados c
        where c.evento_id = p_evento_id
          and c.usuario_id = v_usuario
          and c.actividad_id is null
          and c.tipo = 'participacion'
          and c.estado = 'emitido'
        limit 1;
    end if;

    if v_codigo is null then
        raise exception 'No se pudo generar el certificado.';
    end if;

    return jsonb_build_object(
        'ok', true,
        'codigo', v_codigo,
        'porcentaje_asistencia', v_porcentaje,
        'porcentaje_requerido', v_requerido,
        'mensaje', 'Tu certificado fue generado correctamente.'
    );
end;
$$;


create or replace function public.emitir_mi_certificado(
    p_evento_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.emitir_mi_certificado_impl(p_evento_id);
$$;

-- ============================================================
-- 13. EMISIÓN MANUAL CONTROLADA DE CERTIFICADO - ADMIN
-- Se conserva como respaldo para casos excepcionales.
-- ============================================================

create or replace function private.emitir_certificado_manual_impl(
    p_evento_id uuid,
    p_usuario_id uuid,
    p_tipo text default 'participacion',
    p_actividad_id uuid default null,
    p_pdf_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_admin uuid := auth.uid();
    v_nombre_participante text;
    v_nombre_evento text;
    v_nombre_actividad text;
    v_codigo text;
begin
    if v_admin is null
       or not private.usuario_tiene_rol(array['admin']::text[]) then
        raise exception 'No tienes permiso para emitir certificados.';
    end if;

    if nullif(trim(p_tipo), '') is null then
        raise exception 'El tipo de certificado es obligatorio.';
    end if;

    select trim(
        coalesce(p.nombres, '') || ' ' ||
        coalesce(p.apellidos, '')
    )
    into v_nombre_participante
    from public.perfiles p
    where p.id = p_usuario_id;

    if not found then
        raise exception 'El participante no existe.';
    end if;

    if nullif(trim(v_nombre_participante), '') is null then
        raise exception
            'El participante debe completar sus nombres y apellidos antes de emitir el certificado.';
    end if;

    select e.nombre
    into v_nombre_evento
    from public.eventos e
    where e.id = p_evento_id;

    if not found then
        raise exception 'El evento no existe.';
    end if;

    if p_actividad_id is not null then
        select a.titulo
        into v_nombre_actividad
        from public.actividades a
        where a.id = p_actividad_id
          and a.evento_id = p_evento_id;

        if not found then
            raise exception 'La actividad no pertenece al evento indicado.';
        end if;
    end if;

    if p_actividad_id is null then
        select c.codigo
        into v_codigo
        from public.certificados c
        where c.evento_id = p_evento_id
          and c.usuario_id = p_usuario_id
          and c.actividad_id is null
          and c.tipo = p_tipo
          and c.estado = 'emitido'
        limit 1;
    else
        select c.codigo
        into v_codigo
        from public.certificados c
        where c.actividad_id = p_actividad_id
          and c.usuario_id = p_usuario_id
          and c.tipo = p_tipo
          and c.estado = 'emitido'
        limit 1;
    end if;

    if v_codigo is not null then
        return jsonb_build_object(
            'ok', true,
            'codigo', v_codigo,
            'mensaje', 'El certificado ya estaba emitido.'
        );
    end if;

    insert into public.certificados (
        evento_id,
        actividad_id,
        usuario_id,
        tipo,
        origen_emision,
        nombre_participante,
        nombre_evento,
        nombre_actividad,
        pdf_url,
        emitido_por
    )
    values (
        p_evento_id,
        p_actividad_id,
        p_usuario_id,
        trim(p_tipo),
        'manual_admin',
        v_nombre_participante,
        v_nombre_evento,
        v_nombre_actividad,
        p_pdf_url,
        v_admin
    )
    returning codigo into v_codigo;

    return jsonb_build_object(
        'ok', true,
        'codigo', v_codigo,
        'mensaje', 'Certificado emitido correctamente.'
    );
end;
$$;

create or replace function public.emitir_certificado_manual(
    p_evento_id uuid,
    p_usuario_id uuid,
    p_tipo text default 'participacion',
    p_actividad_id uuid default null,
    p_pdf_url text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
    select private.emitir_certificado_manual_impl(
        p_evento_id,
        p_usuario_id,
        p_tipo,
        p_actividad_id,
        p_pdf_url
    );
$$;

-- ============================================================
-- 14. VERIFICACIÓN PÚBLICA DE CERTIFICADO
-- Usa snapshots históricos y no expone DNI, correo ni teléfono.
-- ============================================================

create or replace function private.verificar_certificado_impl(p_codigo text)
returns table (
    valido boolean,
    codigo text,
    participante text,
    evento text,
    actividad text,
    emitido_en timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        (c.estado = 'emitido') as valido,
        c.codigo,
        c.nombre_participante as participante,
        c.nombre_evento as evento,
        c.nombre_actividad as actividad,
        c.emitido_en
    from public.certificados c
    where c.codigo = upper(trim(p_codigo))
    limit 1;
$$;

create or replace function public.verificar_certificado(p_codigo text)
returns table (
    valido boolean,
    codigo text,
    participante text,
    evento text,
    actividad text,
    emitido_en timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
    select *
    from private.verificar_certificado_impl(p_codigo);
$$;
