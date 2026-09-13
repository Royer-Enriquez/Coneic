-- ============================================================
-- BASE DE DATOS V3 - CANDIDATA PARA PRUEBAS
-- ANIVERSARIO FIC / PRECONGRESO CONEIC 2027
-- Archivo: esquema.sql
-- Ejecutar PRIMERO en un proyecto NUEVO de Supabase.
-- ============================================================

create extension if not exists pgcrypto;

-- Schema interno para funciones auxiliares/privilegiadas.
create schema if not exists private;

revoke all on schema private from public;

-- ============================================================
-- 1. PERFILES
-- auth.users conserva identidad, contraseña y sesión.
-- public.perfiles conserva únicamente datos adicionales.
-- ============================================================

create table public.perfiles (
    id uuid primary key references auth.users(id) on delete cascade,
    nombres text not null default '',
    apellidos text not null default '',
    tipo_documento text not null default 'DNI'
        check (tipo_documento in ('DNI', 'CE', 'PASAPORTE', 'OTRO')),
    documento_identidad text,
    telefono text,
    institucion text,
    carrera text,
    correo text,
    rol text not null default 'participante'
        check (rol in ('participante', 'control', 'admin')),
    activo boolean not null default true,
    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now()
);

-- Evita duplicar documentos por diferencias de mayúsculas/espacios.
create unique index uq_perfiles_documento_normalizado
on public.perfiles (upper(trim(documento_identidad)))
where documento_identidad is not null
  and trim(documento_identidad) <> '';

-- El correo se conserva como copia útil para reportes, pero su fuente real
-- sigue siendo Supabase Auth.
create unique index uq_perfiles_correo_normalizado
on public.perfiles (lower(trim(correo)))
where correo is not null
  and trim(correo) <> '';

-- ============================================================
-- 2. EVENTOS
-- ============================================================

create table public.eventos (
    id uuid primary key default gen_random_uuid(),
    nombre text not null,
    slug text not null,
    descripcion text,

    fecha_inicio timestamptz not null,
    fecha_fin timestamptz,

    lugar text,
    direccion text,

    estado text not null default 'borrador'
        check (estado in ('borrador', 'publicado', 'finalizado', 'cancelado')),

    es_prueba boolean not null default false,

    -- La publicación y la apertura de inscripciones son conceptos distintos.
    inscripciones_abiertas boolean not null default false,
    inscripcion_inicio timestamptz,
    inscripcion_fin timestamptz,

    requiere_pago boolean not null default false,
    enlace_pago text,
    enlace_formulario_pago text,

    porcentaje_minimo_certificado numeric(5,2) not null default 70
        check (porcentaje_minimo_certificado between 0 and 100),

    creado_por uuid references public.perfiles(id) on delete set null,
    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    constraint uq_eventos_slug unique (slug),

    check (trim(nombre) <> ''),
    check (trim(slug) <> ''),
    check (slug = lower(slug)),
    check (fecha_fin is null or fecha_fin >= fecha_inicio),
    check (
        inscripcion_fin is null
        or inscripcion_inicio is null
        or inscripcion_fin >= inscripcion_inicio
    )
);

-- ============================================================
-- 3. INSCRIPCIÓN GENERAL AL EVENTO
-- ============================================================

create table public.inscripciones_evento (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references public.eventos(id) on delete cascade,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,

    estado text not null default 'pendiente'
        check (estado in ('pendiente', 'inscrito', 'cancelado')),

    estado_pago text not null default 'no_requiere'
        check (estado_pago in ('no_requiere', 'pendiente', 'verificado', 'rechazado')),

    medio_pago text,
    referencia_pago text,

    pago_verificado_por uuid references public.perfiles(id) on delete set null,
    pago_verificado_en timestamptz,

    inscrito_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    unique (evento_id, usuario_id),

    check (
        (estado_pago = 'verificado' and pago_verificado_en is not null)
        or estado_pago <> 'verificado'
    ),

    -- Nunca debe existir una inscripción habilitada con pago pendiente/rechazado.
    check (
        estado <> 'inscrito'
        or estado_pago in ('no_requiere', 'verificado')
    ),

    -- Un pago verificado puede quedar inscrito o posteriormente cancelado.
    check (
        estado_pago <> 'verificado'
        or estado in ('inscrito', 'cancelado')
    )
);

-- ============================================================
-- 4. SALAS
-- La asistencia física se controla por sala, no por ponencia.
-- ============================================================

create table public.salas (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references public.eventos(id) on delete cascade,
    nombre text not null,
    ubicacion text,
    activo boolean not null default true,
    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (trim(nombre) <> ''),
    unique (id, evento_id)
);

create unique index uq_salas_evento_nombre
on public.salas(evento_id, lower(trim(nombre)));

create index idx_salas_evento
on public.salas(evento_id);

-- ============================================================
-- 5. ACTIVIDADES
-- Una tabla para ponencias, concursos, talleres, ceremonias, etc.
-- ============================================================

create table public.actividades (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references public.eventos(id) on delete cascade,

    tipo text not null
        check (tipo in ('ponencia', 'concurso', 'taller', 'ceremonia', 'otro')),

    titulo text not null,
    descripcion text,
    imagen_url text,
    enlace_bases text,

    fecha_inicio timestamptz,
    fecha_fin timestamptz,

    -- "lugar" permanece para texto libre visible.
    lugar text,

    -- sala_id permite calcular presencia automáticamente.
    sala_id uuid,
    controla_asistencia boolean not null default false,

    -- Número máximo de INSCRIPCIONES.
    -- Individual = una persona ocupa un cupo.
    -- Equipo = un equipo ocupa un cupo.
    -- Ambos = persona o equipo ocupan un cupo cada uno.
    capacidad integer,

    requiere_inscripcion boolean not null default true,
    inscripciones_abiertas boolean not null default false,
    inscripcion_inicio timestamptz,
    inscripcion_fin timestamptz,

    modalidad_inscripcion text not null default 'individual'
        check (modalidad_inscripcion in ('individual', 'equipo', 'ambos')),

    minimo_integrantes_equipo integer,
    maximo_integrantes_equipo integer,

    cuenta_para_certificado boolean not null default false,

    estado text not null default 'borrador'
        check (estado in ('borrador', 'publicado', 'finalizado', 'cancelado')),

    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (trim(titulo) <> ''),
    check (capacidad is null or capacidad > 0),
    check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio),
    check (
        inscripcion_fin is null
        or inscripcion_inicio is null
        or inscripcion_fin >= inscripcion_inicio
    ),

    check (
        (
            modalidad_inscripcion = 'individual'
            and minimo_integrantes_equipo is null
            and maximo_integrantes_equipo is null
        )
        or
        (
            modalidad_inscripcion in ('equipo', 'ambos')
            and minimo_integrantes_equipo is not null
            and maximo_integrantes_equipo is not null
            and minimo_integrantes_equipo >= 1
            and maximo_integrantes_equipo >= minimo_integrantes_equipo
        )
    ),

    -- Una actividad publicada debe tener fecha de inicio.
    check (estado <> 'publicado' or fecha_inicio is not null),

    -- Si controla asistencia automática, debe tener sala y rango horario completo.
    check (
        controla_asistencia = false
        or (
            sala_id is not null
            and fecha_inicio is not null
            and fecha_fin is not null
        )
    ),

    unique (id, evento_id),

    -- Impide asociar una sala perteneciente a otro evento.
    foreign key (sala_id, evento_id)
        references public.salas(id, evento_id)
        on delete restrict
);

create index idx_actividades_evento on public.actividades(evento_id);
create index idx_actividades_tipo on public.actividades(tipo);
create index idx_actividades_fecha on public.actividades(fecha_inicio);
create index idx_actividades_sala on public.actividades(sala_id);

-- ============================================================
-- 5. PONENTES
-- ============================================================

create table public.ponentes (
    id uuid primary key default gen_random_uuid(),
    nombres text not null,
    apellidos text,
    cargo text,
    institucion text,
    biografia text,
    foto_url text,
    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (trim(nombres) <> '')
);

create table public.actividad_ponentes (
    actividad_id uuid not null references public.actividades(id) on delete cascade,
    ponente_id uuid not null references public.ponentes(id) on delete cascade,
    primary key (actividad_id, ponente_id)
);

create index idx_actividad_ponentes_ponente
on public.actividad_ponentes(ponente_id);

-- ============================================================
-- 6. EQUIPOS
-- ============================================================

create table public.equipos (
    id uuid primary key default gen_random_uuid(),
    actividad_id uuid not null references public.actividades(id) on delete cascade,
    nombre text not null,
    lider_usuario_id uuid not null references public.perfiles(id) on delete cascade,

    codigo_invitacion uuid not null default gen_random_uuid() unique,

    estado text not null default 'formando'
        check (estado in ('formando', 'inscrito', 'cancelado')),

    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (trim(nombre) <> ''),

    -- Necesario para las claves foráneas compuestas.
    unique (id, actividad_id)
);

-- El nombre del equipo no se repite en la misma actividad,
-- ignorando mayúsculas/minúsculas y espacios laterales.
create unique index uq_equipos_nombre_normalizado
on public.equipos (actividad_id, lower(trim(nombre)));

create index idx_equipos_actividad on public.equipos(actividad_id);
create index idx_equipos_lider on public.equipos(lider_usuario_id);

create table public.miembros_equipo (
    id uuid primary key default gen_random_uuid(),

    equipo_id uuid not null,
    actividad_id uuid not null,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,

    rol_equipo text not null default 'miembro'
        check (rol_equipo in ('lider', 'miembro')),

    unido_en timestamptz not null default now(),

    foreign key (equipo_id, actividad_id)
        references public.equipos(id, actividad_id)
        on delete cascade,

    unique (equipo_id, usuario_id),

    -- Un usuario solo puede pertenecer a un equipo por actividad.
    unique (actividad_id, usuario_id)
);

-- Solo puede existir un miembro marcado como líder por equipo.
create unique index uq_miembros_un_lider
on public.miembros_equipo(equipo_id)
where rol_equipo = 'lider';

create index idx_miembros_equipo_usuario
on public.miembros_equipo(usuario_id);

-- ============================================================
-- 7. INSCRIPCIONES A ACTIVIDADES
-- Individual O equipo, nunca ambos en la misma fila.
-- ============================================================

create table public.inscripciones_actividad (
    id uuid primary key default gen_random_uuid(),

    actividad_id uuid not null references public.actividades(id) on delete cascade,
    usuario_id uuid references public.perfiles(id) on delete cascade,
    equipo_id uuid,

    estado text not null default 'inscrito'
        check (estado in ('pendiente', 'inscrito', 'cancelado')),

    inscrito_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (
        (usuario_id is not null and equipo_id is null)
        or
        (usuario_id is null and equipo_id is not null)
    ),

    -- Si es inscripción de equipo, obliga a que el equipo pertenezca
    -- exactamente a la misma actividad.
    foreign key (equipo_id, actividad_id)
        references public.equipos(id, actividad_id)
        on delete cascade
);

create unique index uq_inscripcion_individual
on public.inscripciones_actividad(actividad_id, usuario_id)
where usuario_id is not null;

create unique index uq_inscripcion_equipo
on public.inscripciones_actividad(actividad_id, equipo_id)
where equipo_id is not null;

create index idx_inscripciones_actividad_usuario
on public.inscripciones_actividad(usuario_id);

create index idx_inscripciones_actividad_equipo
on public.inscripciones_actividad(equipo_id);

-- ============================================================
-- 8. CREDENCIALES QR
-- ============================================================

create table public.credenciales_qr (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references public.eventos(id) on delete cascade,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,

    -- El QR contiene este token, no datos personales.
    token uuid not null default gen_random_uuid() unique,

    activo boolean not null default true,

    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    unique (evento_id, usuario_id)
);

create index idx_qr_usuario on public.credenciales_qr(usuario_id);

-- ============================================================
-- 9. CURSOS ACADÉMICOS
-- No existe relación fija "ponencia -> curso".
-- El usuario puede asignar CUALQUIER actividad con asistencia a uno o
-- varios de sus cursos, sin importar el tema de la ponencia.
-- ============================================================

create table public.cursos (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references public.eventos(id) on delete cascade,

    codigo text,
    nombre text not null,
    docente text,
    seccion text,
    ciclo text,

    porcentaje_minimo_asistencia numeric(5,2) not null default 70
        check (porcentaje_minimo_asistencia between 0 and 100),

    permite_autoinscripcion boolean not null default true,
    activo boolean not null default true,

    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    check (trim(nombre) <> ''),
    unique (id, evento_id)
);

create unique index uq_cursos_evento_nombre_seccion
on public.cursos (
    evento_id,
    lower(trim(nombre)),
    lower(trim(coalesce(seccion, '')))
);

create index idx_cursos_evento
on public.cursos(evento_id);

-- Los alumnos indican los cursos que llevan.
-- Esto permite que el reporte incluya también a quienes NO registraron
-- una ponencia para ese curso.
create table public.curso_participantes (
    curso_id uuid not null references public.cursos(id) on delete cascade,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,

    estado text not null default 'activo'
        check (estado in ('activo', 'retirado')),

    origen text not null default 'usuario'
        check (origen in ('usuario', 'admin', 'importado')),

    inscrito_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    primary key (curso_id, usuario_id)
);

create index idx_curso_participantes_usuario
on public.curso_participantes(usuario_id);

-- El usuario decide para qué curso(s) desea usar una ponencia.
-- La misma ponencia puede contar para varios cursos del mismo usuario.
create table public.asignaciones_asistencia_curso (
    id uuid primary key default gen_random_uuid(),

    evento_id uuid not null,
    actividad_id uuid not null,
    curso_id uuid not null,
    usuario_id uuid not null,

    estado text not null default 'seleccionado'
        check (estado in ('seleccionado', 'retirado')),

    seleccionado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    foreign key (actividad_id, evento_id)
        references public.actividades(id, evento_id)
        on delete cascade,

    foreign key (curso_id, evento_id)
        references public.cursos(id, evento_id)
        on delete cascade,

    foreign key (curso_id, usuario_id)
        references public.curso_participantes(curso_id, usuario_id)
        on delete cascade,

    unique (usuario_id, actividad_id, curso_id)
);

create index idx_asignaciones_curso
on public.asignaciones_asistencia_curso(curso_id);

create index idx_asignaciones_actividad
on public.asignaciones_asistencia_curso(actividad_id);

create index idx_asignaciones_usuario
on public.asignaciones_asistencia_curso(usuario_id);

-- ============================================================
-- 10. SESIONES DE PRESENCIA
-- Un usuario puede entrar y salir varias veces de una sala.
-- Ejemplo: mañana -> almuerzo -> tarde.
-- ============================================================

create table public.sesiones_presencia (
    id uuid primary key default gen_random_uuid(),

    evento_id uuid not null,
    sala_id uuid not null,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,

    entrada_en timestamptz not null,
    salida_en timestamptz,

    entrada_registrada_por uuid references public.perfiles(id) on delete set null,
    salida_registrada_por uuid references public.perfiles(id) on delete set null,

    estado text not null default 'registrada'
        check (estado in ('registrada', 'observada', 'anulada')),

    observacion text,

    creado_en timestamptz not null default now(),
    actualizado_en timestamptz not null default now(),

    foreign key (sala_id, evento_id)
        references public.salas(id, evento_id)
        on delete cascade,

    check (salida_en is null or salida_en >= entrada_en)
);

-- Una persona no puede estar "abierta" simultáneamente en dos salas.
create unique index uq_sesion_abierta_usuario
on public.sesiones_presencia(usuario_id)
where salida_en is null and estado <> 'anulada';

create index idx_sesiones_presencia_usuario
on public.sesiones_presencia(usuario_id);

create index idx_sesiones_presencia_sala
on public.sesiones_presencia(sala_id);

create index idx_sesiones_presencia_evento
on public.sesiones_presencia(evento_id);

-- ============================================================
-- 10. CERTIFICADOS
-- Conserva "snapshots" para que un certificado antiguo no cambie
-- si el participante o el evento cambian de nombre después.
-- ============================================================

create table public.certificados (
    id uuid primary key default gen_random_uuid(),

    evento_id uuid not null references public.eventos(id) on delete restrict,
    actividad_id uuid references public.actividades(id) on delete set null,
    usuario_id uuid references public.perfiles(id) on delete set null,

    tipo text not null default 'participacion',

    codigo text not null unique default
        ('CERT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),

    estado text not null default 'emitido'
        check (estado in ('emitido', 'anulado')),

    -- Permite distinguir certificados generados por el propio usuario
    -- de emisiones administrativas excepcionales.
    origen_emision text not null default 'manual_admin'
        check (origen_emision in ('automatico_usuario', 'manual_admin')),

    -- Snapshots del criterio utilizado al momento de emitir.
    -- En certificados manuales pueden permanecer NULL.
    porcentaje_asistencia numeric(5,2)
        check (porcentaje_asistencia is null or porcentaje_asistencia between 0 and 100),

    porcentaje_requerido numeric(5,2)
        check (porcentaje_requerido is null or porcentaje_requerido between 0 and 100),

    -- Copias históricas.
    nombre_participante text not null,
    nombre_evento text not null,
    nombre_actividad text,

    pdf_url text,

    emitido_en timestamptz not null default now(),
    emitido_por uuid references public.perfiles(id) on delete set null,

    check (trim(tipo) <> ''),
    check (trim(nombre_participante) <> ''),
    check (trim(nombre_evento) <> '')
);

create unique index uq_certificado_evento_usuario
on public.certificados(evento_id, usuario_id, tipo)
where actividad_id is null
  and usuario_id is not null
  and estado = 'emitido';

create unique index uq_certificado_actividad_usuario
on public.certificados(actividad_id, usuario_id, tipo)
where actividad_id is not null
  and usuario_id is not null
  and estado = 'emitido';

create index idx_certificados_usuario on public.certificados(usuario_id);
create index idx_certificados_codigo on public.certificados(codigo);

-- ============================================================
-- 11. ÍNDICES ADICIONALES
-- ============================================================

create index idx_inscripciones_evento_usuario
on public.inscripciones_evento(usuario_id);

create index idx_inscripciones_evento_evento_estado
on public.inscripciones_evento(evento_id, estado);

-- ============================================================
-- 12. FUNCIÓN GENÉRICA actualizado_en
-- ============================================================

create or replace function private.actualizar_fecha_modificacion()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    new.actualizado_en = now();
    return new;
end;
$$;

create trigger trg_perfiles_actualizado
before update on public.perfiles
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_eventos_actualizado
before update on public.eventos
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_inscripciones_evento_actualizado
before update on public.inscripciones_evento
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_salas_actualizado
before update on public.salas
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_actividades_actualizado
before update on public.actividades
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_ponentes_actualizado
before update on public.ponentes
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_equipos_actualizado
before update on public.equipos
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_inscripciones_actividad_actualizado
before update on public.inscripciones_actividad
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_qr_actualizado
before update on public.credenciales_qr
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_cursos_actualizado
before update on public.cursos
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_curso_participantes_actualizado
before update on public.curso_participantes
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_asignaciones_asistencia_curso_actualizado
before update on public.asignaciones_asistencia_curso
for each row execute function private.actualizar_fecha_modificacion();

create trigger trg_sesiones_presencia_actualizado
before update on public.sesiones_presencia
for each row execute function private.actualizar_fecha_modificacion();

-- ============================================================
-- 13. PERFIL AUTOMÁTICO AL REGISTRARSE EN AUTH
-- ============================================================

create or replace function private.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.perfiles (
        id,
        nombres,
        apellidos,
        correo
    )
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'nombres', ''),
        coalesce(new.raw_user_meta_data->>'apellidos', ''),
        new.email
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.crear_perfil_nuevo_usuario();

-- Mantiene sincronizada la copia del correo si cambia en Auth.
create or replace function private.sincronizar_correo_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.perfiles
    set correo = new.email
    where id = new.id;

    return new;
end;
$$;

create trigger on_auth_user_email_updated
after update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function private.sincronizar_correo_perfil();

-- ============================================================
-- 14. VALIDACIÓN DE LÍDER DE EQUIPO
-- Evita incoherencia entre equipos.lider_usuario_id y miembros_equipo.
-- ============================================================

create or replace function private.validar_rol_miembro_equipo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_lider uuid;
begin
    select e.lider_usuario_id
    into v_lider
    from public.equipos e
    where e.id = new.equipo_id
      and e.actividad_id = new.actividad_id;

    if v_lider is null then
        raise exception 'El equipo no existe.';
    end if;

    if new.usuario_id = v_lider and new.rol_equipo <> 'lider' then
        raise exception 'El líder del equipo debe estar marcado como líder.';
    end if;

    if new.usuario_id <> v_lider and new.rol_equipo = 'lider' then
        raise exception 'Solo el líder registrado del equipo puede tener rol de líder.';
    end if;

    return new;
end;
$$;

create trigger trg_validar_rol_miembro_equipo
before insert or update on public.miembros_equipo
for each row execute function private.validar_rol_miembro_equipo();

-- ============================================================
-- 15. VALIDACIÓN EVENTO-ACTIVIDAD EN CERTIFICADOS
-- ============================================================

create or replace function private.validar_certificado_evento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_evento_actividad uuid;
begin
    if new.actividad_id is not null then
        select a.evento_id
        into v_evento_actividad
        from public.actividades a
        where a.id = new.actividad_id;

        if v_evento_actividad is null then
            raise exception 'La actividad del certificado no existe.';
        end if;

        if v_evento_actividad <> new.evento_id then
            raise exception 'La actividad no pertenece al evento del certificado.';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_validar_certificado_evento
before insert or update of evento_id, actividad_id
on public.certificados
for each row execute function private.validar_certificado_evento();


-- ============================================================
-- 16. CANCELACIÓN DE EQUIPOS
-- Si un equipo se cancela, su inscripción se marca como cancelada y
-- se liberan sus miembros para que puedan formar/unirse a otro equipo.
-- Se conserva la fila del equipo como referencia administrativa.
-- ============================================================

create or replace function private.procesar_cancelacion_equipo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if old.estado is distinct from new.estado
       and new.estado = 'cancelado' then

        update public.inscripciones_actividad
        set estado = 'cancelado',
            actualizado_en = now()
        where equipo_id = new.id
          and estado <> 'cancelado';

        delete from public.miembros_equipo
        where equipo_id = new.id;
    end if;

    return new;
end;
$$;

create trigger trg_procesar_cancelacion_equipo
after update of estado on public.equipos
for each row execute function private.procesar_cancelacion_equipo();
