-- ============================================================
-- V3.2 - PREPARAR USUARIOS DE PRUEBA PARA CURSOS
-- Ejecutar DESPUÉS de crear los usuarios de Auth.
-- ============================================================

insert into public.curso_participantes (
    curso_id, usuario_id, estado, origen
)
select
    '12000000-0000-0000-0000-000000000001'::uuid,
    p.id,
    'activo',
    'admin'
from public.perfiles p
where p.correo in (
    'participante1@example.com',
    'participante2@example.com',
    'participante3@example.com'
)
on conflict (curso_id, usuario_id)
do update set estado = 'activo', actualizado_en = now();

insert into public.curso_participantes (
    curso_id, usuario_id, estado, origen
)
select
    '12000000-0000-0000-0000-000000000002'::uuid,
    p.id,
    'activo',
    'admin'
from public.perfiles p
where p.correo in (
    'participante1@example.com',
    'participante2@example.com',
    'participante3@example.com'
)
on conflict (curso_id, usuario_id)
do update set estado = 'activo', actualizado_en = now();
