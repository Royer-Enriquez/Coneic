-- ============================================================
-- V3.2.1 - PERMISOS DE AUTOEMISIÓN DE CERTIFICADOS
-- Ejecutar DESPUÉS de funciones-v3_2_1-migracion.sql
-- ============================================================

revoke execute on function
    private.calcular_elegibilidad_certificado_impl(uuid, uuid)
from public, anon;

revoke execute on function
    private.mi_elegibilidad_certificado_impl(uuid)
from public, anon;

revoke execute on function
    private.emitir_mi_certificado_impl(uuid)
from public, anon;

revoke execute on function
    public.mi_elegibilidad_certificado(uuid)
from public, anon;

revoke execute on function
    public.emitir_mi_certificado(uuid)
from public, anon;

grant usage on schema private to authenticated;

grant execute on function
    private.calcular_elegibilidad_certificado_impl(uuid, uuid)
to authenticated;

grant execute on function
    private.mi_elegibilidad_certificado_impl(uuid)
to authenticated;

grant execute on function
    private.emitir_mi_certificado_impl(uuid)
to authenticated;

grant execute on function
    public.mi_elegibilidad_certificado(uuid)
to authenticated;

grant execute on function
    public.emitir_mi_certificado(uuid)
to authenticated;

-- La política INSERT de certificados NO se abre a participantes.
-- La autoemisión ocurre únicamente dentro de la función SECURITY DEFINER.
