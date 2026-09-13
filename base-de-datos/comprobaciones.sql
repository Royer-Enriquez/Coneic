-- ============================================================
-- BASE DE DATOS V3.2 - COMPROBACIONES ESTRUCTURALES
-- ============================================================

with esperadas(nombre) as (
    values
        ('perfiles'),
        ('eventos'),
        ('inscripciones_evento'),
        ('salas'),
        ('actividades'),
        ('ponentes'),
        ('actividad_ponentes'),
        ('equipos'),
        ('miembros_equipo'),
        ('inscripciones_actividad'),
        ('credenciales_qr'),
        ('cursos'),
        ('curso_participantes'),
        ('asignaciones_asistencia_curso'),
        ('sesiones_presencia'),
        ('certificados')
)
select
    nombre,
    to_regclass('public.' || nombre) is not null as existe
from esperadas
order by nombre;

select
    c.relname as tabla,
    c.relrowsecurity as rls_activo
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
      'perfiles','eventos','inscripciones_evento','salas','actividades',
      'ponentes','actividad_ponentes','equipos','miembros_equipo',
      'inscripciones_actividad','credenciales_qr','cursos',
      'curso_participantes','asignaciones_asistencia_curso',
      'sesiones_presencia','certificados'
  )
order by c.relname;

with funciones(firma) as (
    values
        ('public.inscribirse_evento(uuid)'),
        ('public.verificar_pago_evento(uuid,boolean,text)'),
        ('public.inscribirse_actividad(uuid)'),
        ('public.crear_equipo(uuid,text)'),
        ('public.unirse_equipo(uuid)'),
        ('public.inscribir_equipo_actividad(uuid)'),
        ('public.obtener_o_crear_qr(uuid)'),
        ('public.regenerar_qr(uuid)'),
        ('public.agregar_mi_curso(uuid)'),
        ('public.seleccionar_curso_asistencia(uuid,uuid)'),
        ('public.quitar_curso_asistencia(uuid,uuid)'),
        ('public.registrar_escaneo_sala(uuid,uuid)'),
        ('public.mi_asistencia_evento(uuid)'),
        ('public.reporte_asistencia_curso(uuid,uuid)'),
        ('public.mi_elegibilidad_certificado(uuid)'),
        ('public.emitir_mi_certificado(uuid)'),
        ('public.emitir_certificado_manual(uuid,uuid,text,uuid,text)'),
        ('public.verificar_certificado(text)')
)
select
    firma,
    to_regprocedure(firma) is not null as existe
from funciones
order by firma;

-- Debe dar 0: más de una sesión abierta por usuario.
select usuario_id, count(*) as sesiones_abiertas
from public.sesiones_presencia
where salida_en is null
  and estado <> 'anulada'
group by usuario_id
having count(*) > 1;

-- Debe dar 0: actividad asociada a sala de otro evento.
select a.id, a.evento_id, a.sala_id, s.evento_id as evento_sala
from public.actividades a
join public.salas s on s.id = a.sala_id
where a.evento_id <> s.evento_id;

-- Debe dar 0: asignación curso-actividad cruzando eventos.
select
    ac.id,
    ac.evento_id,
    a.evento_id as evento_actividad,
    c.evento_id as evento_curso
from public.asignaciones_asistencia_curso ac
join public.actividades a on a.id = ac.actividad_id
join public.cursos c on c.id = ac.curso_id
where ac.evento_id <> a.evento_id
   or ac.evento_id <> c.evento_id;

-- Debe dar 0: sesiones con salida anterior a entrada.
select *
from public.sesiones_presencia
where salida_en is not null
  and salida_en < entrada_en;


-- V3.2.1: el origen de emisión debe ser válido.
select *
from public.certificados
where origen_emision not in ('automatico_usuario', 'manual_admin');

-- V3.2.1: porcentajes históricos fuera de rango deben dar 0 filas.
select *
from public.certificados
where (porcentaje_asistencia is not null
       and porcentaje_asistencia not between 0 and 100)
   or (porcentaje_requerido is not null
       and porcentaje_requerido not between 0 and 100);
