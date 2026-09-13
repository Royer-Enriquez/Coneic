
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

