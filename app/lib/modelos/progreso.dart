/// Dónde había quedado el visitante en una misión (SIS03).
///
/// Sólo existe para quien tiene cuenta: sin ella no hay dónde guardar nada y
/// la API devuelve null, que es como funcionó el museo hasta ahora.
class ProgresoMision {
  /// Los desafíos que ya resolvió, por id.
  ///
  /// Van los ids y no una posición porque el administrador pudo agregar o
  /// borrar desafíos desde la última vez, y una posición apuntaría a otro.
  final List<int> resueltos;

  /// Los puntos que lleva ganados en esta vuelta.
  final int puntos;

  /// Las pistas que ya pagó en el desafío donde retoma. Se las devuelve el
  /// servidor para no cobrárselas de nuevo por haber cerrado la app.
  final List<String> pistas;

  const ProgresoMision({
    required this.resueltos,
    required this.puntos,
    required this.pistas,
  });

  /// Si hay algo que retomar. Un progreso recién abierto viene vacío.
  bool get hayAvance => resueltos.isNotEmpty || puntos > 0 || pistas.isNotEmpty;

  factory ProgresoMision.desdeJson(Map<String, dynamic> json) {
    return ProgresoMision(
      resueltos: ((json['resueltos'] as List?) ?? const []).whereType<int>().toList(),
      puntos: (json['puntos'] as int?) ?? 0,
      pistas: ((json['pistas'] as List?) ?? const []).whereType<String>().toList(),
    );
  }
}
