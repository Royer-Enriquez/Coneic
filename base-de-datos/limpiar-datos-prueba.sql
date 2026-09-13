-- ============================================================
-- V3.2 - LIMPIAR DATOS DE PRUEBA
-- ============================================================

delete from public.certificados
where evento_id in (
    select id from public.eventos where es_prueba = true
);

delete from public.eventos
where es_prueba = true;

delete from public.ponentes
where id = '20000000-0000-0000-0000-000000000001';
