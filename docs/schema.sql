-- =====================================================================
--  Exploradores del Museo
--  Esquema de base de datos (PostgreSQL 16)
--  Compatible con Supabase
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------
CREATE TYPE rol_usuario        AS ENUM ('visitante', 'administrador');
CREATE TYPE dificultad_mision  AS ENUM ('facil', 'media', 'dificil');
CREATE TYPE tipo_identificador AS ENUM ('qr', 'nfc');
CREATE TYPE tipo_desafio       AS ENUM ('pregunta_opcion_multiple',
                                        'respuesta_corta',
                                        'escaneo_objeto',
                                        'busqueda_guiada');
CREATE TYPE estado_progreso    AS ENUM ('en_curso', 'completada', 'abandonada');
CREATE TYPE tipo_evento        AS ENUM ('mision_iniciada',
                                        'desafio_iniciado',
                                        'respuesta_correcta',
                                        'respuesta_incorrecta',
                                        'pista_usada',
                                        'objeto_escaneado',
                                        'mision_completada',
                                        'insignia_obtenida');

-- ---------------------------------------------------------------------
-- 1. USUARIOS  (historias SIS04, y autenticación del panel)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id              BIGSERIAL     PRIMARY KEY,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    password_hash   VARCHAR(255)  NOT NULL,
    nombre          VARCHAR(120)  NOT NULL,
    rol             rol_usuario   NOT NULL DEFAULT 'visitante',
    activo          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_email_formato CHECK (email LIKE '%_@_%._%')
);

COMMENT ON TABLE usuarios IS
    'Visitantes y administradores. La contraseña se guarda hasheada con bcrypt (SIS04).';

-- ---------------------------------------------------------------------
-- 2. SALAS  (estructura física del museo)
-- ---------------------------------------------------------------------
CREATE TABLE salas (
    id              SERIAL        PRIMARY KEY,
    nombre          VARCHAR(150)  NOT NULL UNIQUE,
    nivel           VARCHAR(50),
    area_tematica   VARCHAR(100)  NOT NULL,
    orden_recorrido SMALLINT      NOT NULL,
    CONSTRAINT chk_orden_recorrido CHECK (orden_recorrido > 0)
);

COMMENT ON COLUMN salas.orden_recorrido IS
    'Posición dentro del recorrido propuesto por el museo.';

-- ---------------------------------------------------------------------
-- 3. CATEGORIAS  (historia ADM23)
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
    id      SERIAL       PRIMARY KEY,
    nombre  VARCHAR(80)  NOT NULL UNIQUE
);

COMMENT ON TABLE categorias IS
    'Clasificacion tematica de los objetos, definida por cada museo segun su acervo '
    '(paleontologia, pintura, indumentaria, etc.). El esquema no presupone una tematica.';

-- ---------------------------------------------------------------------
-- 4. OBJETOS DEL MUSEO  (historias ADM15, ADM16, ADM17, ADM23)
-- ---------------------------------------------------------------------
CREATE TABLE objetos (
    id                  BIGSERIAL           PRIMARY KEY,
    sala_id             INTEGER             NOT NULL
                        REFERENCES salas(id) ON DELETE RESTRICT,
    categoria_id        INTEGER
                        REFERENCES categorias(id) ON DELETE SET NULL,
    nombre              VARCHAR(200)        NOT NULL,
    descripcion         TEXT,
    dato_clave          TEXT                NOT NULL,
    imagen_url          TEXT,
    tipo_identificador  tipo_identificador  NOT NULL DEFAULT 'qr',
    codigo              VARCHAR(120)        NOT NULL UNIQUE,
    activo              BOOLEAN             NOT NULL DEFAULT TRUE,
    creado_en           TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_objetos_sala      ON objetos(sala_id);
CREATE INDEX idx_objetos_categoria ON objetos(categoria_id);
CREATE INDEX idx_objetos_codigo    ON objetos(codigo);

COMMENT ON COLUMN objetos.codigo IS
    'Contenido del QR/NFC pegado junto a la pieza. Es único: permite validar el escaneo (SIS01).';
COMMENT ON COLUMN objetos.dato_clave IS
    'Información que se muestra al visitante al escanear y base para las preguntas.';

-- ---------------------------------------------------------------------
-- 5. MISIONES  (historias ADM01 a ADM07)
-- ---------------------------------------------------------------------
CREATE TABLE misiones (
    id                  BIGSERIAL          PRIMARY KEY,
    nombre              VARCHAR(200)       NOT NULL,
    descripcion         TEXT               NOT NULL,
    imagen_url          TEXT,
    dificultad          dificultad_mision  NOT NULL DEFAULT 'media',
    duracion_estimada   SMALLINT           NOT NULL,
    activa              BOOLEAN            NOT NULL DEFAULT FALSE,
    archivada           BOOLEAN            NOT NULL DEFAULT FALSE,
    mision_previa_id    BIGINT
                        REFERENCES misiones(id) ON DELETE SET NULL,
    creada_por          BIGINT
                        REFERENCES usuarios(id) ON DELETE SET NULL,
    creada_en           TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_duracion     CHECK (duracion_estimada BETWEEN 1 AND 240),
    CONSTRAINT chk_no_autoprevia CHECK (mision_previa_id IS NULL OR mision_previa_id <> id),
    -- NOT NULL no alcanza: un texto vacio o de solo espacios no es NULL (ADM02).
    -- '\S' exige al menos un caracter que no sea espacio, tabulacion ni salto.
    CONSTRAINT chk_nombre_con_texto      CHECK (nombre ~ '\S'),
    CONSTRAINT chk_descripcion_con_texto CHECK (descripcion ~ '\S')
);

CREATE INDEX idx_misiones_activas ON misiones(activa) WHERE archivada = FALSE;

COMMENT ON COLUMN misiones.mision_previa_id IS
    'Misión que debe completarse antes de desbloquear esta (historia VIS12).';
COMMENT ON COLUMN misiones.archivada IS
    'Baja lógica: conserva el historial de progreso en lugar de borrarlo (ADM07).';

-- ---------------------------------------------------------------------
-- 6. DESAFIOS  (historias ADM08 a ADM12, ADM14, ADM18)
-- ---------------------------------------------------------------------
CREATE TABLE desafios (
    id                  BIGSERIAL      PRIMARY KEY,
    mision_id           BIGINT         NOT NULL
                        REFERENCES misiones(id) ON DELETE CASCADE,
    objeto_id           BIGINT
                        REFERENCES objetos(id) ON DELETE RESTRICT,
    orden               SMALLINT       NOT NULL,
    tipo                tipo_desafio   NOT NULL,
    enunciado           TEXT           NOT NULL,
    configuracion       JSONB          NOT NULL DEFAULT '{}'::JSONB,
    respuesta_correcta  TEXT,
    puntos              SMALLINT       NOT NULL DEFAULT 10,
    CONSTRAINT chk_puntos CHECK (puntos >= 0),
    CONSTRAINT chk_orden  CHECK (orden > 0),
    CONSTRAINT uq_desafio_orden UNIQUE (mision_id, orden) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_desafios_mision ON desafios(mision_id);
CREATE INDEX idx_desafios_objeto ON desafios(objeto_id);

COMMENT ON COLUMN desafios.configuracion IS
    'Contenido variable segun el tipo de desafio (opciones, tolerancia de respuesta, etc.). '
    'Se usa JSONB para no crear una tabla por tipo, manteniendo el resto del modelo relacional.';

-- ---------------------------------------------------------------------
-- 7. PISTAS  (historias ADM13, VIS07)
-- ---------------------------------------------------------------------
CREATE TABLE pistas (
    id              BIGSERIAL  PRIMARY KEY,
    desafio_id      BIGINT     NOT NULL
                    REFERENCES desafios(id) ON DELETE CASCADE,
    orden           SMALLINT   NOT NULL DEFAULT 1,
    texto           TEXT       NOT NULL,
    penalizacion    SMALLINT   NOT NULL DEFAULT 0,
    CONSTRAINT chk_penalizacion CHECK (penalizacion >= 0),
    CONSTRAINT uq_pista_orden   UNIQUE (desafio_id, orden)
);

CREATE INDEX idx_pistas_desafio ON pistas(desafio_id);

-- ---------------------------------------------------------------------
-- 8. INSIGNIAS  (historias ADM19, ADM20, VIS10)
-- ---------------------------------------------------------------------
CREATE TABLE insignias (
    id          SERIAL        PRIMARY KEY,
    nombre      VARCHAR(120)  NOT NULL UNIQUE,
    descripcion TEXT          NOT NULL,
    icono_url   TEXT,
    condicion   JSONB         NOT NULL,
    activa      BOOLEAN       NOT NULL DEFAULT TRUE
);

COMMENT ON COLUMN insignias.condicion IS
    'Regla evaluada automaticamente. Ej: {"tipo":"misiones_completadas","misiones":[3,4,5]}';

-- ---------------------------------------------------------------------
-- 9. RECOMPENSAS  (historia ADM21)
-- ---------------------------------------------------------------------
CREATE TABLE recompensas (
    id          SERIAL        PRIMARY KEY,
    mision_id   BIGINT        REFERENCES misiones(id) ON DELETE CASCADE,
    nombre      VARCHAR(120)  NOT NULL,
    descripcion TEXT,
    condicion   JSONB         NOT NULL DEFAULT '{}'::JSONB
);

-- ---------------------------------------------------------------------
-- 10. PROGRESO DE MISION  (historias VIS09, VIS11, SIS03)
-- ---------------------------------------------------------------------
CREATE TABLE progreso_misiones (
    id                BIGSERIAL        PRIMARY KEY,
    usuario_id        BIGINT           NOT NULL
                      REFERENCES usuarios(id) ON DELETE CASCADE,
    mision_id         BIGINT           NOT NULL
                      REFERENCES misiones(id) ON DELETE CASCADE,
    estado            estado_progreso  NOT NULL DEFAULT 'en_curso',
    puntos_obtenidos  INTEGER          NOT NULL DEFAULT 0,
    iniciada_en       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    finalizada_en     TIMESTAMPTZ,
    CONSTRAINT chk_puntos_progreso CHECK (puntos_obtenidos >= 0),
    CONSTRAINT chk_fecha_fin CHECK (finalizada_en IS NULL OR finalizada_en >= iniciada_en),
    CONSTRAINT chk_estado_fin CHECK (
        (estado = 'completada' AND finalizada_en IS NOT NULL)
        OR estado <> 'completada')
);

CREATE INDEX idx_progreso_usuario ON progreso_misiones(usuario_id);
CREATE INDEX idx_progreso_mision  ON progreso_misiones(mision_id);
CREATE UNIQUE INDEX uq_mision_en_curso
    ON progreso_misiones(usuario_id, mision_id)
    WHERE estado = 'en_curso';

COMMENT ON INDEX uq_mision_en_curso IS
    'Un visitante no puede tener la misma mision iniciada dos veces en paralelo.';

-- ---------------------------------------------------------------------
-- 11. PROGRESO DE DESAFIO  (historias VIS08, SIS02, SIS03)
-- ---------------------------------------------------------------------
CREATE TABLE progreso_desafios (
    id                    BIGSERIAL    PRIMARY KEY,
    progreso_mision_id    BIGINT       NOT NULL
                          REFERENCES progreso_misiones(id) ON DELETE CASCADE,
    desafio_id            BIGINT       NOT NULL
                          REFERENCES desafios(id) ON DELETE CASCADE,
    completado            BOOLEAN      NOT NULL DEFAULT FALSE,
    intentos              SMALLINT     NOT NULL DEFAULT 0,
    pistas_usadas         SMALLINT     NOT NULL DEFAULT 0,
    puntos_obtenidos      SMALLINT     NOT NULL DEFAULT 0,
    respondido_en         TIMESTAMPTZ,
    CONSTRAINT chk_intentos CHECK (intentos >= 0),
    CONSTRAINT chk_pistas   CHECK (pistas_usadas >= 0),
    CONSTRAINT uq_progreso_desafio UNIQUE (progreso_mision_id, desafio_id)
);

CREATE INDEX idx_pd_progreso ON progreso_desafios(progreso_mision_id);
CREATE INDEX idx_pd_desafio  ON progreso_desafios(desafio_id);

-- ---------------------------------------------------------------------
-- 12. INSIGNIAS OBTENIDAS  (historia VIS10)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios_insignias (
    usuario_id   BIGINT       NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
    insignia_id  INTEGER      NOT NULL REFERENCES insignias(id) ON DELETE CASCADE,
    obtenida_en  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (usuario_id, insignia_id)
);

-- ---------------------------------------------------------------------
-- 13. EVENTOS  (historias SIS02 y ADM22 — analitica)
-- ---------------------------------------------------------------------
CREATE TABLE eventos (
    id                  BIGSERIAL    PRIMARY KEY,
    usuario_id          BIGINT       REFERENCES usuarios(id) ON DELETE SET NULL,
    progreso_mision_id  BIGINT       REFERENCES progreso_misiones(id) ON DELETE CASCADE,
    desafio_id          BIGINT       REFERENCES desafios(id) ON DELETE SET NULL,
    tipo                tipo_evento  NOT NULL,
    datos               JSONB        NOT NULL DEFAULT '{}'::JSONB,
    ocurrido_en         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_eventos_tipo   ON eventos(tipo);
CREATE INDEX idx_eventos_fecha  ON eventos(ocurrido_en);
CREATE INDEX idx_eventos_mision ON eventos(progreso_mision_id);

COMMENT ON TABLE eventos IS
    'Bitacora de interacciones. Alimenta las estadisticas de uso del panel (ADM22).';

-- ---------------------------------------------------------------------
-- Trigger: mantener actualizada la fecha de modificacion de misiones
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_actualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_misiones_actualizada
    BEFORE UPDATE ON misiones
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_timestamp();

-- ---------------------------------------------------------------------
-- Vista de apoyo para el modulo de analitica (ADM22)
-- ---------------------------------------------------------------------
-- Nota: las pistas se agregan en una subconsulta aparte. Si se unieran
-- progreso_misiones y progreso_desafios en el mismo FROM, cada participacion
-- se repetiria una vez por desafio e inflaria los conteos.
CREATE VIEW v_estadisticas_misiones AS
SELECT
    m.id                                                        AS mision_id,
    m.nombre                                                    AS mision,
    COUNT(pm.id)                                                AS veces_iniciada,
    COUNT(pm.id) FILTER (WHERE pm.estado = 'completada')        AS veces_completada,
    ROUND(AVG(EXTRACT(EPOCH FROM (pm.finalizada_en - pm.iniciada_en)) / 60.0)
          FILTER (WHERE pm.estado = 'completada')::NUMERIC, 1)  AS minutos_promedio,
    COALESCE(p.pistas_usadas, 0)                                AS pistas_usadas
FROM misiones m
LEFT JOIN progreso_misiones pm ON pm.mision_id = m.id
LEFT JOIN (
    SELECT pm2.mision_id, SUM(pd.pistas_usadas) AS pistas_usadas
    FROM progreso_misiones pm2
    JOIN progreso_desafios pd ON pd.progreso_mision_id = pm2.id
    GROUP BY pm2.mision_id
) p ON p.mision_id = m.id
GROUP BY m.id, m.nombre, p.pistas_usadas;

-- ---------------------------------------------------------------------
-- Seguridad: cerrar el acceso publico a traves de la API REST
-- ---------------------------------------------------------------------
-- Supabase expone automaticamente el esquema public como API REST. Sin Row
-- Level Security, cualquiera con la clave publicable (que viaja dentro de la
-- app y por lo tanto es publica) puede leer y escribir todas las tablas.
-- Verificado: antes de esto, un GET a /rest/v1/usuarios devolvia los hashes
-- de contrasena desde internet y un POST insertaba filas sin autenticacion.
--
-- Se activa RLS SIN crear politicas. Eso bloquea por completo el acceso desde
-- la API REST. El backend Express no se ve afectado porque conecta con la
-- cadena de conexion de PostgreSQL, y el dueno de las tablas ignora RLS.
-- El control de acceso vive en la API (JWT + roles), no en la base.

ALTER TABLE usuarios           ENABLE ROW LEVEL SECURITY;
ALTER TABLE salas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias         ENABLE ROW LEVEL SECURITY;
ALTER TABLE objetos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE misiones           ENABLE ROW LEVEL SECURITY;
ALTER TABLE desafios           ENABLE ROW LEVEL SECURITY;
ALTER TABLE pistas             ENABLE ROW LEVEL SECURITY;
ALTER TABLE insignias          ENABLE ROW LEVEL SECURITY;
ALTER TABLE recompensas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE progreso_misiones  ENABLE ROW LEVEL SECURITY;
ALTER TABLE progreso_desafios  ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios_insignias ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos            ENABLE ROW LEVEL SECURITY;

-- La vista corria con los permisos de quien la creo, salteando el RLS de las
-- tablas que consulta. Con security_invoker usa los permisos de quien consulta.
ALTER VIEW v_estadisticas_misiones SET (security_invoker = on);

-- Sin search_path fijo, un atacante puede anteponer un esquema propio para que
-- la funcion resuelva NOW() a codigo suyo. Con search_path vacio solo resuelve
-- contra pg_catalog, que siempre esta disponible.
ALTER FUNCTION fn_actualizar_timestamp() SET search_path = '';
