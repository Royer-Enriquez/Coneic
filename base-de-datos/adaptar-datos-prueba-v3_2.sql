-- ============================================================
-- ADAPTAR DATOS DE PRUEBA EXISTENTES A V3.2
-- Ejecutar SOLO en el proyecto DEV actual, después de la migración.
-- ============================================================

insert into public.salas (
    id, evento_id, nombre, ubicacion, activo
)
values
(
    '11000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Auditorio de prueba',
    'Primer piso',
    true
),
(
    '11000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Sala secundaria de prueba',
    'Segundo piso',
    true
)
on conflict (id) do nothing;

update public.actividades
set
    sala_id = '11000000-0000-0000-0000-000000000001',
    controla_asistencia = true,
    fecha_inicio = now() - interval '10 minutes',
    fecha_fin = now() + interval '50 minutes'
where id = '30000000-0000-0000-0000-000000000001';

-- La ceremonia/tercera actividad antigua puede quedar sin control.
-- Para probar cambio automático de ponencia, creamos una segunda ponencia.
insert into public.actividades (
    id, evento_id, tipo, titulo, descripcion,
    fecha_inicio, fecha_fin, lugar, sala_id, controla_asistencia,
    requiere_inscripcion, inscripciones_abiertas,
    modalidad_inscripcion, cuenta_para_certificado, estado
)
values (
    '30000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'ponencia',
    'Segunda ponencia V3.2 de prueba',
    'Misma sala, horario posterior, sin necesidad de nuevo escaneo.',
    now() + interval '50 minutes',
    now() + interval '1 hour 50 minutes',
    'Auditorio de prueba',
    '11000000-0000-0000-0000-000000000001',
    true,
    false,
    false,
    'individual',
    true,
    'publicado'
)
on conflict (id) do nothing;

insert into public.cursos (
    id, evento_id, codigo, nombre, docente, seccion, ciclo,
    porcentaje_minimo_asistencia, permite_autoinscripcion, activo
)
values
(
    '12000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'MS-PRUEBA',
    'Mecánica de Suelos - Prueba',
    'Docente de prueba',
    'A',
    '2026-II',
    70,
    true,
    true
),
(
    '12000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'DV-PRUEBA',
    'Diseño Vial - Prueba',
    'Docente de prueba',
    'A',
    '2026-II',
    80,
    true,
    true
)
on conflict (id) do nothing;

insert into public.curso_participantes (
    curso_id, usuario_id, estado, origen
)
select
    c.id,
    p.id,
    'activo',
    'admin'
from public.cursos c
cross join public.perfiles p
where c.id in (
    '12000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000002'
)
and p.correo in (
    'participante1@example.com',
    'participante2@example.com',
    'participante3@example.com'
)
on conflict (curso_id, usuario_id)
do update set estado = 'activo', actualizado_en = now();
