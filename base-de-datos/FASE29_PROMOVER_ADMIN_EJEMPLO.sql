-- EJECUTA ESTE SCRIPT SOLO DESPUES DE REGISTRAR TU CUENTA DESDE LA WEB.
-- Sustituye el correo antes de ejecutar.

update public.perfiles
set rol = 'admin', activo = true, actualizado_en = now()
where lower(trim(correo)) = lower(trim('TU_CORREO@EJEMPLO.COM'));

select id, nombres, apellidos, correo, rol, activo
from public.perfiles
where lower(trim(correo)) = lower(trim('TU_CORREO@EJEMPLO.COM'));
