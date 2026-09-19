-- =====================================================================
--  Datos de prueba - caso de ejemplo: Museo de La Plata
-- =====================================================================

-- ---------- Usuarios ----------
INSERT INTO usuarios (email, password_hash, nombre, rol) VALUES
('admin@museo.test',  '$2b$10$ejemploHashBcryptNoEsUnaClaveReal000000000000000000', 'Administrador del Museo', 'administrador'),
('visitante@correo.test', '$2b$10$ejemploHashBcryptNoEsUnaClaveReal111111111111111111', 'Camila Ruiz', 'visitante');

-- ---------- Categorías ----------
INSERT INTO categorias (nombre) VALUES
('Geología'), ('Mineralogía'), ('Paleontología'), ('Paleobotánica'),
('Zoología'), ('Entomología'), ('Antropología'), ('Arqueología'),
('Etnografía'), ('Historia');

-- ---------- Salas ----------
INSERT INTO salas (nombre, nivel, area_tematica, orden_recorrido) VALUES
('La Tierra: una historia de cambios',                'Planta baja', 'Geología',        1),
('Tiempo y Materia: laberintos de la evolución',      'Planta baja', 'Evolución',       2),
('Vida en la Tierra. Precámbrico y Paleozoico',       'Planta baja', 'Paleontología',   3),
('Era Mesozoica. Edad de los Reptiles',               'Planta baja', 'Paleontología',   4),
('Era Cenozoica. Megafauna de América del Sur',       'Planta baja', 'Paleontología',   5),
('Gran Intercambio Biótico Americano',                'Planta baja', 'Paleontología',   6),
('Extinción de la Megafauna. Edad de Hielo',          'Planta baja', 'Paleontología',   7),
('Diversidad y hábitos de los Invertebrados',         'Planta baja', 'Zoología',        8),
('Entomología. La vida de los Insectos',              'Planta baja', 'Zoología',        9),
('Diversidad de Aves y Mamíferos',                    'Planta baja', 'Zoología',       10),
('Diversidad de Anfibios y Reptiles',                 'Planta baja', 'Zoología',       11),
('Osteología comparada. Exhibición histórica',        'Planta baja', 'Anatomía',       12),
('Vertebrados acuáticos y semiacuáticos',             'Planta baja', 'Zoología',       13),
('Evolución humana. Ser y Pertenecer',                'Planta alta', 'Antropología',   14),
('Etnografía. Espejos culturales',                    'Planta alta', 'Etnografía',     15),
('Arqueología Latinoamericana',                       'Planta alta', 'Arqueología',    16),
('Arqueología del Noroeste Argentino',                'Planta alta', 'Arqueología',    17),
('Sala Egipcia. Fragmentos de Historia a orillas del Nilo', 'Planta alta', 'Arqueología', 18),
('Sala Moreno. Época fundacional',                    'Planta alta', 'Historia',       19),
('Colección jesuítica',                               'Planta alta', 'Historia',       20);

-- ---------- Objetos ----------
INSERT INTO objetos (sala_id, categoria_id, nombre, dato_clave, codigo) VALUES
((SELECT id FROM salas WHERE nombre LIKE 'La Tierra%'),
 (SELECT id FROM categorias WHERE nombre='Geología'),
 'Meteorito Capper',
 'Hallado por Francisco P. Moreno en 1896 en la provincia de Chubut.',
 'MLP-OBJ-001'),

((SELECT id FROM salas WHERE nombre LIKE 'La Tierra%'),
 (SELECT id FROM categorias WHERE nombre='Mineralogía'),
 'Geoda de cuarzo con amatista',
 'Procedente de los Altos del Río Uruguay. Las geodas son cavidades tapizadas de cristales.',
 'MLP-OBJ-002'),

((SELECT id FROM salas WHERE nombre LIKE 'Tiempo y Materia%'),
 (SELECT id FROM categorias WHERE nombre='Paleontología'),
 'Réplica de Diplodocus carnegii',
 'Saurópodo de 150 millones de años. Mide 27,2 m de largo y 4,3 m de alto. Se exhibe desde 1912.',
 'MLP-OBJ-005'),

((SELECT id FROM salas WHERE nombre LIKE 'Tiempo y Materia%'),
 (SELECT id FROM categorias WHERE nombre='Paleontología'),
 'Fémur de Antarctosaurus',
 'Dinosaurio herbívoro de la Patagonia, de 60 a 80 millones de años, hallado en Río Negro.',
 'MLP-OBJ-006'),

((SELECT id FROM salas WHERE nombre LIKE 'Era Mesozoica%'),
 (SELECT id FROM categorias WHERE nombre='Paleontología'),
 'Esqueleto de Neuquensaurus',
 'Saurópodo herbívoro del tamaño de un elefante, habitó la Patagonia hace unos 80 millones de años.',
 'MLP-OBJ-015'),

((SELECT id FROM salas WHERE nombre LIKE 'Era Cenozoica%'),
 (SELECT id FROM categorias WHERE nombre='Paleontología'),
 'Esqueleto de Megaterio',
 'La especie de mayor porte de la Megafauna: hasta 5 m de alto y unos 4.000 kg.',
 'MLP-OBJ-018'),

((SELECT id FROM salas WHERE nombre LIKE 'Sala Egipcia%'),
 (SELECT id FROM categorias WHERE nombre='Arqueología'),
 'Sarcófagos y momias egipcias',
 'Dos sarcófagos de la época tardía donados por Dardo Rocha, estudiados por tomografía.',
 'MLP-OBJ-064');

-- ---------- Misiones ----------
INSERT INTO misiones (nombre, descripcion, dificultad, duracion_estimada, activa, creada_por) VALUES
('Los guardianes del tiempo',
 'Recorré la sala La Tierra y descubrí cómo se formó nuestro planeta.',
 'facil', 20, TRUE, 1),
('El gigante de Pittsburgh',
 'La historia del Diplodocus, el esqueleto más grande del Museo.',
 'facil', 15, TRUE, 1),
('Cazadores de fósiles',
 'Identificá los reptiles que dominaron la Era Mesozoica.',
 'media', 25, TRUE, 1);

-- La tercera misión se desbloquea al completar la segunda
UPDATE misiones SET mision_previa_id = 2 WHERE id = 3;

-- ---------- Desafíos ----------
INSERT INTO desafios (mision_id, objeto_id, orden, tipo, enunciado, configuracion, respuesta_correcta, puntos) VALUES
(2, (SELECT id FROM objetos WHERE codigo='MLP-OBJ-005'), 1, 'escaneo_objeto',
 'Encontrá el esqueleto del dinosaurio más grande del Museo y escaneá su código.',
 '{}', NULL, 10),

(2, (SELECT id FROM objetos WHERE codigo='MLP-OBJ-005'), 2, 'pregunta_opcion_multiple',
 '¿Cuántos metros de largo mide el Diplodocus del Museo?',
 '{"opciones":["18,5 metros","27,2 metros","33,0 metros","12,4 metros"]}',
 '27,2 metros', 10),

(2, (SELECT id FROM objetos WHERE codigo='MLP-OBJ-006'), 3, 'respuesta_corta',
 '¿En qué provincia se hallaron los restos del Antarctosaurus?',
 '{"tolerancia":"flexible"}', 'Río Negro', 10),

(1, (SELECT id FROM objetos WHERE codigo='MLP-OBJ-001'), 1, 'respuesta_corta',
 '¿En qué provincia halló Moreno el meteorito Capper?',
 '{"tolerancia":"flexible"}', 'Chubut', 10),

(1, (SELECT id FROM objetos WHERE codigo='MLP-OBJ-002'), 2, 'busqueda_guiada',
 'Buscá la piedra que por dentro está tapizada de cristales violetas.',
 '{}', NULL, 15);

-- ---------- Pistas ----------
INSERT INTO pistas (desafio_id, orden, texto, penalizacion) VALUES
(2, 1, 'Es más largo que dos colectivos juntos.', 3),
(3, 1, 'Está en la Patagonia argentina, al sur del río Colorado.', 3),
(4, 1, 'Está en la Patagonia, es la provincia de Puerto Madryn.', 3),
(5, 1, 'Se llama geoda y proviene del Río Uruguay.', 5);

-- ---------- Insignias ----------
INSERT INTO insignias (nombre, descripcion, condicion) VALUES
('Paleontólogo junior', 'Completaste las misiones de paleontología.',
 '{"tipo":"misiones_completadas","misiones":[2,3]}'),
('Experto en minerales', 'Completaste Los guardianes del tiempo sin usar pistas.',
 '{"tipo":"mision_sin_pistas","mision":1}'),
('Ojo de halcón', 'Resolviste 10 desafíos de escaneo sin errores.',
 '{"tipo":"escaneos_sin_error","cantidad":10}');

-- ---------- Recompensas ----------
INSERT INTO recompensas (mision_id, nombre, descripcion, condicion) VALUES
(2, 'Ficha del Diplodocus', 'Ficha digital descargable con la historia de la pieza.',
 '{"tipo":"completar_mision"}');

-- ---------- Progreso de ejemplo ----------
INSERT INTO progreso_misiones (usuario_id, mision_id, estado, puntos_obtenidos, iniciada_en, finalizada_en)
VALUES (2, 2, 'completada', 27, NOW() - INTERVAL '40 minutes', NOW() - INTERVAL '22 minutes');

INSERT INTO progreso_desafios (progreso_mision_id, desafio_id, completado, intentos, pistas_usadas, puntos_obtenidos, respondido_en) VALUES
(1, 1, TRUE, 1, 0, 10, NOW() - INTERVAL '36 minutes'),
(1, 2, TRUE, 2, 1, 7,  NOW() - INTERVAL '30 minutes'),
(1, 3, TRUE, 1, 0, 10, NOW() - INTERVAL '23 minutes');

INSERT INTO usuarios_insignias (usuario_id, insignia_id) VALUES (2, 1);

INSERT INTO eventos (usuario_id, progreso_mision_id, desafio_id, tipo, datos) VALUES
(2, 1, 1, 'mision_iniciada',      '{"origen":"listado"}'),
(2, 1, 1, 'objeto_escaneado',     '{"codigo":"MLP-OBJ-005"}'),
(2, 1, 2, 'respuesta_incorrecta', '{"respuesta":"33,0 metros"}'),
(2, 1, 2, 'pista_usada',          '{"pista_id":1}'),
(2, 1, 2, 'respuesta_correcta',   '{"respuesta":"27,2 metros"}'),
(2, 1, 3, 'respuesta_correcta',   '{"respuesta":"Rio Negro"}'),
(2, 1, NULL, 'mision_completada', '{"puntos":27}');
