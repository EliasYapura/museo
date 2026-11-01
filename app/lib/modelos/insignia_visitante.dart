/// Una insignia tal como la ve el visitante (VIS10).
///
/// No es la misma [Insignia] que usa la administración: acá no están la
/// condición ni si se sigue otorgando. Lo que importa de este lado es qué es y
/// si ya la ganó.
class InsigniaVisitante {
  final int id;
  final String nombre;

  /// Lo que escribió el museo: por qué se gana.
  final String descripcion;

  final String? iconoUrl;

  /// Cuándo la ganó. Null si todavía no la tiene, y siempre null para quien
  /// recorre sin cuenta: sin cuenta no hay dónde guardarlas.
  final DateTime? obtenidaEn;

  const InsigniaVisitante({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.iconoUrl,
    required this.obtenidaEn,
  });

  bool get obtenida => obtenidaEn != null;

  factory InsigniaVisitante.desdeJson(Map<String, dynamic> json) {
    final fecha = json['obtenida_en'] as String?;
    return InsigniaVisitante(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      iconoUrl: json['icono_url'] as String?,
      // Una fecha que no se entiende no tira la pantalla abajo: la insignia se
      // muestra igual, como no obtenida.
      obtenidaEn: fecha == null ? null : DateTime.tryParse(fecha),
    );
  }
}
