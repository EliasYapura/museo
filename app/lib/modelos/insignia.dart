/// Una insignia del museo, vista desde la administración (ADM19).
///
/// Es un logro que el visitante gana al cumplir una condición. La condición se
/// carga aparte (ADM20): una insignia recién creada viene con la condición
/// vacía, que significa que todavía no la puede ganar nadie.
class Insignia {
  final int id;
  final String nombre;

  /// Lo que lee el visitante cuando la gana: por qué se la dieron.
  final String descripcion;

  final String? iconoUrl;

  /// La regla que se evalúa para otorgarla, tal como la guarda la base. Vacía
  /// mientras no se le haya cargado ninguna.
  final Map<String, dynamic> condicion;

  /// Si se sigue otorgando. Desactivarla no se la quita a nadie que ya la
  /// tenga; eso sólo pasa al borrarla.
  final bool activa;

  /// A cuántos visitantes ya se les otorgó. Importa antes de borrar: borrar
  /// una insignia se la quita a todos ellos.
  final int obtenidaPor;

  const Insignia({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.iconoUrl,
    required this.condicion,
    required this.activa,
    required this.obtenidaPor,
  });

  /// Si ya tiene una regla cargada y se puede ganar.
  bool get sePuedeGanar => condicion.isNotEmpty;

  /// El tipo de condición, cuando tiene una. Es lo que va a editar ADM20.
  String? get tipoDeCondicion => condicion['tipo'] as String?;

  factory Insignia.desdeJson(Map<String, dynamic> json) {
    return Insignia(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      iconoUrl: json['icono_url'] as String?,
      condicion: (json['condicion'] as Map?)?.cast<String, dynamic>() ?? const {},
      activa: json['activa'] as bool? ?? true,
      obtenidaPor: (json['obtenida_por'] as int?) ?? 0,
    );
  }
}
