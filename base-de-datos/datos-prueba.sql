-- ============================================================
-- BASE DE DATOS V3.2 - DATOS DE PRUEBA
-- Ejecutar después de esquema.sql + funciones.sql + permisos.sql.
-- NO crea usuarios de Auth.
-- ============================================================

insert into public.eventos (
    id, nombre, slug, descripcion,
    fecha_inicio, fecha_fin, lugar,
    estado, es_prueba, inscripciones_abiertas,
    requiere_pago, porcentaje_minimo_certificado
)
values
(
    '10000000-0000-0000-0000-000000000001',
    'EVENTO GRATUITO DE PRUEBA',
    'evento-gratuito-prueba',
    'Evento ficticio para probar registro, cursos, QR y presencia.',
    now() - interval '2 hours',
    now() + interval '8 hours',
    'Lugar de prueba',
    'publicado', true, true, false, 70
),
(
    '10000000-0000-0000-0000-000000000002',
    'EVENTO CON PAGO DE PRUEBA',
    'evento-pago-prueba',
    'Evento ficticio para probar pago manual.',
    now() - interval '2 hours',
    now() + interval '8 hours',
    'Lugar de prueba',
    'publicado', true, true, true, 70
)
on conflict (id) do nothing;

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

insert into public.ponentes (
    id, nombres, apellidos, cargo, institucion, biografia
)
values (
    '20000000-0000-0000-0000-000000000001',
    'Ponente',
    'De Prueba',
    'Cargo ficticio',
    'Institución ficticia',
    'Registro utilizado únicamente para comprobar el sistema.'
)
on conflict (id) do nothing;

insert into public.actividades (
    id, evento_id, tipo, titulo, descripcion,
    fecha_inicio, fecha_fin, lugar, sala_id, controla_asistencia,
    capacidad, requiere_inscripcion, inscripciones_abiertas,
    modalidad_inscripcion, cuenta_para_certificado, estado
)
values
(
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'ponencia',
    'Ponencia interna de prueba',
    'Prueba de presencia automática por sala.',
    now() - interval '10 minutes',
    now() + interval '50 minutes',
    'Auditorio de prueba',
    '11000000-0000-0000-0000-000000000001',
    true,
    100, true, true, 'individual', true, 'publicado'
),
(
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'concurso',
    'Concurso interno por equipos',
    'Prueba de creación e inscripción de equipos.',
    now() + interval '1 hour',
    now() + interval '3 hours',
    'Zona de prueba',
    null,
    false,
    20, true, true, 'equipo', false, 'publicado'
),
(
    '30000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'ponencia',
    'Segunda ponencia interna de prueba',
    'Sirve para probar cambio automático de ponencia sin escaneo.',
    now() + interval '50 minutes',
    now() + interval '1 hour 50 minutes',
    'Auditorio de prueba',
    '11000000-0000-0000-0000-000000000001',
    true,
    null, false, false, 'individual', true, 'publicado'
)
on conflict (id) do nothing;

insert into public.actividad_ponentes (actividad_id, ponente_id)
values (
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001'
)
on conflict do nothing;
