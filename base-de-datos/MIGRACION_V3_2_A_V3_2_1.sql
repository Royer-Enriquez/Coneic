-- ============================================================
-- MIGRACIÓN V3.2 -> V3.2.1
-- AUTOEMISIÓN SEGURA DE CERTIFICADOS
-- ============================================================

begin;

alter table public.certificados
    add column if not exists origen_emision text
        not null
        default 'manual_admin';

alter table public.certificados
    drop constraint if exists certificados_origen_emision_check;

alter table public.certificados
    add constraint certificados_origen_emision_check
    check (origen_emision in ('automatico_usuario', 'manual_admin'));

alter table public.certificados
    add column if not exists porcentaje_asistencia numeric(5,2);

alter table public.certificados
    add column if not exists porcentaje_requerido numeric(5,2);

alter table public.certificados
    drop constraint if exists certificados_porcentaje_asistencia_check;

alter table public.certificados
    add constraint certificados_porcentaje_asistencia_check
    check (
        porcentaje_asistencia is null
        or porcentaje_asistencia between 0 and 100
    );

alter table public.certificados
    drop constraint if exists certificados_porcentaje_requerido_check;

alter table public.certificados
    add constraint certificados_porcentaje_requerido_check
    check (
        porcentaje_requerido is null
        or porcentaje_requerido between 0 and 100
    );

commit;
