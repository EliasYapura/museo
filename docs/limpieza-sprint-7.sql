-- Limpieza del Sprint 7: saca de la base lo que quedó sin uso.
--
-- Correr en Supabase > SQL Editor. Es lo mismo que ya se sacó de schema.sql en
-- el commit TEC23: esto deja la base igual que el esquema del repositorio.
--
-- Las dos cosas están sin uso de verdad, comprobado contra el código:
--
--   recompensas              era de ADM21, la historia de las recompensas por
--                            misión, que se descartó en el Sprint 6. Ninguna
--                            ruta la lee ni la escribe. En la base hay una
--                            fila de ejemplo que vino con la semilla.
--
--   v_estadisticas_misiones  la vista de apoyo para ADM22 que se diseñó en el
--                            Sprint 1. ADM22 terminó contando las
--                            participaciones desde la bitácora de eventos y no
--                            desde el progreso, porque el progreso existe sólo
--                            para quien tiene cuenta: medido sobre los datos
--                            reales, una misión con 13 participaciones tiene 3
--                            progresos. La vista se quedó contando las 3.
--
-- Las dos se pueden recuperar del esquema en el tag sprint-7-entrega si algún
-- día hicieran falta.

DROP VIEW IF EXISTS v_estadisticas_misiones;

DROP TABLE IF EXISTS recompensas;

-- Para confirmar que quedaron las trece tablas que corresponden:
--
--   SELECT table_name FROM information_schema.tables
--    WHERE table_schema = 'public' ORDER BY table_name;
--
-- usuarios, salas, categorias, objetos, misiones, desafios, pistas, insignias,
-- progreso_misiones, progreso_desafios, usuarios_insignias, eventos,
-- valoraciones.
