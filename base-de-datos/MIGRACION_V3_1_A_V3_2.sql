-- ============================================================
-- MIGRACIÓN V3.1 -> V3.2
-- PARA EL PROYECTO SUPABASE ACTUAL
-- ============================================================
-- IMPORTANTE:
-- 1. Esta migración reemplaza el modelo antiguo de asistencia por actividad.
-- 2. La tabla public.asistencias de V3.1 contiene SOLO datos de prueba.
-- 3. Esos registros antiguos se eliminan; Auth, perfiles, pagos, equipos,
--    inscripciones, QR y certificados permanecen.
-- ============================================================

begin;

-- Eliminar función antigua de escaneo por actividad.
drop function if exists public.registrar_escaneo_qr(uuid, uuid);
drop function if exists private.registrar_escaneo_qr_impl(uuid, uuid);

-- Eliminar tabla antigua de asistencia (datos ficticios de desarrollo).
drop table if exists public.asistencias cascade;

-- SALAS
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

create index idx_salas_evento on public.salas(evento_id);

-- ACTIVIDADES
alter table public.actividades
    add column sala_id uuid,
    add column controla_asistencia boolean not null default false;

alter table public.actividades
    add constraint uq_actividades_id_evento unique (id, evento_id);

alter table public.actividades
    add constraint fk_actividades_sala_evento
    foreign key (sala_id, evento_id)
    references public.salas(id, evento_id)
    on delete set null;

alter table public.actividades
    add constraint ck_actividades_control_asistencia
    check (
        controla_asistencia = false
        or (
            sala_id is not null
            and fecha_inicio is not null
            and fecha_fin is not null
        )
    );

create index idx_actividades_sala on public.actividades(sala_id);

-- CURSOS
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

create index idx_cursos_evento on public.cursos(evento_id);

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

-- SESIONES DE PRESENCIA
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

create unique index uq_sesion_abierta_usuario
on public.sesiones_presencia(usuario_id)
where salida_en is null and estado <> 'anulada';

create index idx_sesiones_presencia_usuario
on public.sesiones_presencia(usuario_id);
create index idx_sesiones_presencia_sala
on public.sesiones_presencia(sala_id);
create index idx_sesiones_presencia_evento
on public.sesiones_presencia(evento_id);

-- TRIGGERS actualizado_en
create trigger trg_salas_actualizado
before update on public.salas
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

commit;

-- ============================================================
-- DESPUÉS DE ESTA MIGRACIÓN:
-- Ejecutar el archivo:
--   funciones-v3_2-migracion.sql
-- y luego:
--   permisos-v3_2-migracion.sql
-- ============================================================
