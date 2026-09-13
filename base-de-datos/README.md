# BASE DE DATOS V3.2.1 — CANDIDATA PARA PRUEBAS

## Si instalas desde cero

Ejecutar:

```text
1. esquema.sql
2. funciones.sql
3. permisos.sql
4. datos-prueba.sql
5. comprobaciones.sql
```

Después de crear usuarios de Auth:

```text
preparar-usuarios-prueba-cursos.sql
```

## Si YA tienes V3.1 en Supabase

Tu caso actual.

NO ejecutes el esquema completo otra vez.

Ejecuta:

```text
1. MIGRACION_V3_1_A_V3_2.sql
2. funciones-v3_2-migracion.sql
3. permisos-v3_2-migracion.sql
4. adaptar-datos-prueba-v3_2.sql
5. comprobaciones.sql
```

## Idea de V3.2

```text
QR
↓
presencia por SALA
↓
múltiples entradas/salidas
↓
cruce automático con horarios de ponencias
↓
porcentaje real de presencia
```

El usuario puede asignar cualquier ponencia con asistencia a cualquiera de sus
cursos. No existe una relación temática obligatoria entre ponencia y curso.

## Excel

La base entrega el reporte estructurado mediante:

```text
reporte_asistencia_curso()
```

El módulo `reportes` convertirá esas filas a XLSX/CSV. La base de datos no
necesita almacenar archivos Excel.

## Estado

```text
V3.2 = CANDIDATA PARA PRUEBAS
```


## Importante para el proyecto DEV actual

La migración elimina `public.asistencias` de V3.1 porque ese modelo ya no se usa.
En este momento esa tabla contiene únicamente las asistencias ficticias creadas
durante las pruebas. No ejecutar esta migración sobre datos reales sin una
migración histórica específica.


## Actualización V3.2 -> V3.2.1

Si el proyecto Supabase ya tiene V3.2, ejecutar únicamente:

```text
1. MIGRACION_V3_2_A_V3_2_1.sql
2. funciones-v3_2_1-migracion.sql
3. permisos-v3_2_1-migracion.sql
4. comprobaciones.sql
```

La V3.2.1 añade autoemisión segura de certificados por el participante.
La emisión administrativa se mantiene como respaldo.


## Opción simplificada de actualización

Para el proyecto DEV que ya está en V3.2 también se incluye:

```text
ACTUALIZACION_V3_2_A_V3_2_1_COMPLETA.sql
```

Ese archivo reúne la migración estructural, las funciones nuevas y sus permisos.
Se ejecuta una sola vez y reemplaza la necesidad de ejecutar los tres archivos
de migración por separado.
