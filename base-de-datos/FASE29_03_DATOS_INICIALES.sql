-- ============================================================
-- DATOS DEMO PARA PROBAR LA INTEGRACIÓN FASE 29
-- Ejecutar DESPUÉS de:
--   1) esquema.sql
--   2) funciones.sql
--   3) permisos.sql
--   4) FASE29_01_COMPATIBILIDAD.sql
--   5) FASE29_02_INTEGRACION.sql
--
-- IMPORTANTE:
-- - Este script deja el evento SIN pago obligatorio para que puedas probar
--   registro -> inscripción -> QR -> escaneo sin una pasarela de pagos.
-- - Antes de producción, revisa fechas, nombres, capacidades y activa pago
--   si realmente lo necesitas.
-- ============================================================

do $$
declare
  v_evento uuid;
  v_sala_auditorio uuid;
  v_sala_talleres uuid;
begin
  insert into public.eventos (
    nombre, slug, descripcion,
    fecha_inicio, fecha_fin,
    lugar, direccion,
    estado, es_prueba,
    inscripciones_abiertas, inscripcion_inicio, inscripcion_fin,
    requiere_pago, porcentaje_minimo_certificado
  ) values (
    'CONEIC Huancayo 2027',
    'coneic-huancayo-2027',
    'Evento de demostración funcional para la integración Fase 29.',
    '2027-11-12 08:00:00-05',
    '2027-11-14 18:00:00-05',
    'Huancayo, Junín, Perú',
    'Configura aquí la sede y dirección definitivas',
    'publicado', false,
    true, '2026-09-01 00:00:00-05', '2027-11-11 23:59:59-05',
    false, 70
  )
  on conflict (slug) do update set
    nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    fecha_inicio = excluded.fecha_inicio,
    fecha_fin = excluded.fecha_fin,
    lugar = excluded.lugar,
    estado = 'publicado',
    es_prueba = false,
    inscripciones_abiertas = true,
    actualizado_en = now()
  returning id into v_evento;

  -- Tarifas de entrada que la interfaz Fase 29 muestra por defecto.
  -- Son la fuente de verdad para el monto que la RPC registra; el navegador
  -- no puede sustituir el precio enviando otro valor.
  insert into public.tarifas_fase29(evento_id, clave, nombre, monto, activo)
  values
    (v_evento, 'estandar', 'Estándar', 80, true),
    (v_evento, 'vip', 'VIP', 130, true),
    (v_evento, 'premium', 'Premium', 190, true)
  on conflict (evento_id, clave) do update set
    nombre = excluded.nombre,
    monto = excluded.monto,
    activo = true,
    actualizado_en = now();

  select id into v_sala_auditorio
  from public.salas
  where evento_id = v_evento and lower(trim(nombre)) = 'auditorio principal'
  limit 1;
  if v_sala_auditorio is null then
    insert into public.salas(evento_id, nombre, ubicacion, activo)
    values (v_evento, 'Auditorio principal', 'Sede principal', true)
    returning id into v_sala_auditorio;
  end if;

  select id into v_sala_talleres
  from public.salas
  where evento_id = v_evento and lower(trim(nombre)) = 'sala de talleres'
  limit 1;
  if v_sala_talleres is null then
    insert into public.salas(evento_id, nombre, ubicacion, activo)
    values (v_evento, 'Sala de talleres', 'Bloque académico', true)
    returning id into v_sala_talleres;
  end if;

  -- Actividades que cuentan para el certificado.
  if not exists (select 1 from public.actividades where evento_id=v_evento and titulo='Ceremonia de apertura') then
    insert into public.actividades(
      evento_id,tipo,titulo,descripcion,fecha_inicio,fecha_fin,lugar,sala_id,
      controla_asistencia,requiere_inscripcion,inscripciones_abiertas,
      modalidad_inscripcion,cuenta_para_certificado,estado
    ) values (
      v_evento,'ceremonia','Ceremonia de apertura','Apertura oficial del evento.',
      '2027-11-12 08:30:00-05','2027-11-12 10:00:00-05','Auditorio principal',v_sala_auditorio,
      true,false,false,'individual',true,'publicado'
    );
  end if;

  if not exists (select 1 from public.actividades where evento_id=v_evento and titulo='Conferencia magistral inaugural') then
    insert into public.actividades(
      evento_id,tipo,titulo,descripcion,fecha_inicio,fecha_fin,lugar,sala_id,
      controla_asistencia,requiere_inscripcion,inscripciones_abiertas,
      modalidad_inscripcion,cuenta_para_certificado,estado
    ) values (
      v_evento,'ponencia','Conferencia magistral inaugural','Ponencia principal del primer día.',
      '2027-11-12 10:15:00-05','2027-11-12 12:15:00-05','Auditorio principal',v_sala_auditorio,
      true,false,false,'individual',true,'publicado'
    );
  end if;

  -- Talleres: los títulos coinciden exactamente con la interfaz Fase 29.
  if not exists (select 1 from public.actividades where evento_id=v_evento and titulo='Diseño sismorresistente aplicado') then
    insert into public.actividades(
      evento_id,tipo,titulo,descripcion,fecha_inicio,fecha_fin,lugar,sala_id,
      controla_asistencia,capacidad,requiere_inscripcion,inscripciones_abiertas,
      inscripcion_inicio,inscripcion_fin,modalidad_inscripcion,cuenta_para_certificado,estado
    ) values (
      v_evento,'taller','Diseño sismorresistente aplicado','Fundamentos y casos prácticos de diseño estructural ante sismos.',
      '2027-11-12 14:00:00-05','2027-11-12 16:00:00-05','Sala de talleres',v_sala_talleres,
      false,40,true,true,'2026-09-01 00:00:00-05','2027-11-12 13:30:00-05','individual',false,'publicado'
    );
  end if;

  if not exists (select 1 from public.actividades where evento_id=v_evento and titulo='BIM para proyectos de infraestructura') then
    insert into public.actividades(
      evento_id,tipo,titulo,descripcion,fecha_inicio,fecha_fin,lugar,sala_id,
      controla_asistencia,capacidad,requiere_inscripcion,inscripciones_abiertas,
      inscripcion_inicio,inscripcion_fin,modalidad_inscripcion,cuenta_para_certificado,estado
    ) values (
      v_evento,'taller','BIM para proyectos de infraestructura','Modelado colaborativo aplicado a proyectos viales y de edificación.',
      '2027-11-13 09:00:00-05','2027-11-13 11:00:00-05','Sala de talleres',v_sala_talleres,
      false,40,true,true,'2026-09-01 00:00:00-05','2027-11-13 08:30:00-05','individual',false,'publicado'
    );
  end if;

  if not exists (select 1 from public.actividades where evento_id=v_evento and titulo='Gestión ágil de proyectos de construcción') then
    insert into public.actividades(
      evento_id,tipo,titulo,descripcion,fecha_inicio,fecha_fin,lugar,sala_id,
      controla_asistencia,capacidad,requiere_inscripcion,inscripciones_abiertas,
      inscripcion_inicio,inscripcion_fin,modalidad_inscripcion,cuenta_para_certificado,estado
    ) values (
      v_evento,'taller','Gestión ágil de proyectos de construcción','Metodologías ágiles aplicadas a obras civiles.',
      '2027-11-13 14:00:00-05','2027-11-13 16:00:00-05','Sala de talleres',v_sala_talleres,
      false,30,true,true,'2026-09-01 00:00:00-05','2027-11-13 13:30:00-05','individual',false,'publicado'
    );
  end if;
end $$;

-- Si quieres activar pago obligatorio posteriormente, edita los enlaces y ejecuta:
-- update public.eventos
-- set requiere_pago = true,
--     enlace_pago = 'https://TU-ENLACE-DE-PAGO-O-YAPE',
--     actualizado_en = now()
-- where slug = 'coneic-huancayo-2027';
