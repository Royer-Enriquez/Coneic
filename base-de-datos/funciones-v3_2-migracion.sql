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

