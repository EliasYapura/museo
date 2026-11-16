import 'mision.dart' show Dificultad;

/// Una misión vista desde la administración.
///
/// Es distinta de [Mision], la del visitante: acá importa si está publicada,
/// cuándo se modificó y la imagen que se cargó; allá importan los puntos y las
/// salas del recorrido. Mezclarlas obligaría a que casi todos los campos
/// fueran opcionales y ninguna pantalla sabría cuáles puede usar.
class MisionAdmin {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final Dificultad dificultad;
  final int duracionMin;
  final bool activa;
  final int desafios;
  final DateTime? actualizadaEn;

  /// Cuántos visitantes la calificaron (ADM26).
  final int valoraciones;

  /// El promedio de estrellas, o null si todavía nadie la calificó. Null y no
  /// cero: cero sería "la calificaron mal", que no es lo mismo que "nadie la
  /// calificó".
  final double? promedio;

  /// Cuántos pusieron cada puntuación, de 1 a 5 estrellas. Siempre cinco
  /// números: los que nadie eligió vienen en cero.
  ///
  /// Sólo lo manda el detalle; en el listado llega vacío, donde no se usa.
  final List<int> reparto;

  const MisionAdmin({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.imagenUrl,
    required this.dificultad,
    required this.duracionMin,
    required this.activa,
    required this.desafios,
    required this.actualizadaEn,
    this.valoraciones = 0,
    this.promedio,
    this.reparto = const [],
  });

  /// Una misión sin desafíos no se puede publicar: no habría nada que resolver.
  bool get sePuedePublicar => activa || desafios > 0;

  /// El promedio como se escribe en español: una decimal y con coma. Vacío si
  /// todavía nadie la calificó.
  String get promedioEnTexto =>
      promedio == null ? '' : promedio!.toStringAsFixed(1).replaceAll('.', ',');

  /// El listado no manda descripción ni imagen; el detalle sí. Los que faltan
  /// quedan vacíos y los completa la pantalla de la misión al abrirla.
  factory MisionAdmin.desdeJson(Map<String, dynamic> json) {
    return MisionAdmin(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: (json['descripcion'] as String?) ?? '',
      imagenUrl: json['imagen_url'] as String?,
      dificultad: Dificultad.values.firstWhere(
        (d) => d.name == json['dificultad'],
        orElse: () => Dificultad.media,
      ),
      duracionMin: json['duracion_estimada'] as int,
      activa: (json['activa'] as bool?) ?? false,
      desafios: (json['desafios'] as int?) ?? 0,
      actualizadaEn: DateTime.tryParse((json['actualizada_en'] as String?) ?? '')?.toLocal(),
      valoraciones: (json['valoraciones'] as int?) ?? 0,
      // La API manda el promedio como número, pero puede venir entero (4 y no
      // 4.0): num y después toDouble() acepta las dos formas.
      promedio: (json['valoracion_promedio'] as num?)?.toDouble(),
      reparto: ((json['reparto_valoraciones'] as List?) ?? const [])
          .map((n) => (n as num).toInt())
          .toList(),
    );
  }
}
