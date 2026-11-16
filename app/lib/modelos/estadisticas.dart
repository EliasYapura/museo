/// Las estadísticas de uso que ve el administrador (ADM22).
///
/// Los números vienen de dos lugares distintos y eso importa al mostrarlos:
///
/// - Las participaciones, los aciertos, los fallos y las pistas salen de la
///   bitácora de eventos, que registra a todos los visitantes, con cuenta y
///   sin cuenta.
/// - Los tiempos salen del progreso guardado, que existe sólo para quien tiene
///   cuenta. Por eso [UsoDeMision.participacionesMedidas] casi siempre es
///   menor que [UsoDeMision.participaciones], y la pantalla lo aclara en vez
///   de dejar que parezca un error.
library;

/// El resumen de todo el museo.
class ResumenDeUso {
  final int participaciones;
  final int completadas;
  final int pistas;
  final int fallos;
  final int aciertos;

  /// Cuántas de las participaciones fueron de visitantes sin cuenta.
  final int participacionesSinCuenta;

  /// Cuándo se registró el primer evento, para poder decir desde cuándo se
  /// mide. Sin eventos es null.
  final DateTime? desde;

  const ResumenDeUso({
    required this.participaciones,
    required this.completadas,
    required this.pistas,
    required this.fallos,
    required this.aciertos,
    required this.participacionesSinCuenta,
    required this.desde,
  });

  /// Qué proporción de las misiones empezadas se terminó, redondeado.
  int? get porcentajeCompletado =>
      participaciones == 0 ? null : (completadas * 100 / participaciones).round();

  factory ResumenDeUso.desdeJson(Map<String, dynamic> json) {
    return ResumenDeUso(
      participaciones: (json['participaciones'] as int?) ?? 0,
      completadas: (json['completadas'] as int?) ?? 0,
      pistas: (json['pistas'] as int?) ?? 0,
      fallos: (json['fallos'] as int?) ?? 0,
      aciertos: (json['aciertos'] as int?) ?? 0,
      participacionesSinCuenta: (json['participaciones_sin_cuenta'] as int?) ?? 0,
      desde: DateTime.tryParse((json['desde'] as String?) ?? '')?.toLocal(),
    );
  }
}

/// Cómo le va a una misión.
class UsoDeMision {
  final int id;
  final String nombre;
  final bool activa;

  final int participaciones;
  final int completadas;
  final int fallos;
  final int pistas;

  /// El tiempo mediano en minutos, o null si todavía no hay ninguna
  /// participación que se pueda medir.
  ///
  /// Es la mediana y no el promedio: con el promedio, una sola participación
  /// que quedó abierta un día entero arruina el número de toda la misión.
  final double? minutosMediana;

  /// Sobre cuántas participaciones se calculó el tiempo.
  final int participacionesMedidas;

  /// Cuántas se descartaron por figurar terminadas más de un día después de
  /// empezar. No miden cuánto tarda la gente: miden que alguien dejó la app
  /// abierta y volvió al otro día.
  final int participacionesSinMedir;

  /// Los minutos que el museo estimó para la misión, para poder comparar con
  /// el tiempo real. Sólo viene en el detalle.
  final int? duracionEstimada;

  const UsoDeMision({
    required this.id,
    required this.nombre,
    required this.activa,
    required this.participaciones,
    required this.completadas,
    required this.fallos,
    required this.pistas,
    required this.minutosMediana,
    required this.participacionesMedidas,
    required this.participacionesSinMedir,
    this.duracionEstimada,
  });

  int? get porcentajeCompletado =>
      participaciones == 0 ? null : (completadas * 100 / participaciones).round();

  /// El tiempo como se escribe en español, con coma. Vacío si no se pudo medir.
  String get tiempoEnTexto {
    final minutos = minutosMediana;
    if (minutos == null) return '';
    // Sin decimal cuando no aporta: "18 min" se lee mejor que "18,0 min".
    if (minutos == minutos.roundToDouble()) return '${minutos.round()} min';
    return '${minutos.toStringAsFixed(1).replaceAll('.', ',')} min';
  }

  factory UsoDeMision.desdeJson(Map<String, dynamic> json) {
    return UsoDeMision(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      activa: (json['activa'] as bool?) ?? false,
      participaciones: (json['participaciones'] as int?) ?? 0,
      completadas: (json['completadas'] as int?) ?? 0,
      fallos: (json['fallos'] as int?) ?? 0,
      pistas: (json['pistas'] as int?) ?? 0,
      // num y no double: la API manda 18 cuando el número es redondo.
      minutosMediana: (json['minutos_mediana'] as num?)?.toDouble(),
      participacionesMedidas: (json['participaciones_medidas'] as int?) ?? 0,
      participacionesSinMedir: (json['participaciones_sin_medir'] as int?) ?? 0,
      duracionEstimada: json['duracion_estimada'] as int?,
    );
  }
}

/// Cómo le va a un desafío dentro de su misión.
///
/// Es la parte del tablero que señala qué corregir: muchos fallos y muchas
/// pistas en el mismo desafío es un desafío mal escrito.
class UsoDeDesafio {
  final int id;
  final int orden;
  final String tipo;
  final String enunciado;

  /// Respuestas correctas y escaneos de la pieza correcta.
  final int aciertos;

  /// Respuestas incorrectas y escaneos de la pieza equivocada. Las dos cosas
  /// son el visitante intentando y no logrando, que es lo que hay que medir.
  final int fallos;

  final int pistas;

  const UsoDeDesafio({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.enunciado,
    required this.aciertos,
    required this.fallos,
    required this.pistas,
  });

  int get intentos => aciertos + fallos;

  /// De cada diez intentos, cuántos salieron bien. Null si todavía no se
  /// intentó: cero diría "siempre falla", que no es lo mismo.
  int? get porcentajeAcierto =>
      intentos == 0 ? null : (aciertos * 100 / intentos).round();

  factory UsoDeDesafio.desdeJson(Map<String, dynamic> json) {
    return UsoDeDesafio(
      id: json['id'] as int,
      orden: (json['orden'] as int?) ?? 0,
      tipo: (json['tipo'] as String?) ?? '',
      enunciado: (json['enunciado'] as String?) ?? '',
      aciertos: (json['aciertos'] as int?) ?? 0,
      fallos: (json['fallos'] as int?) ?? 0,
      pistas: (json['pistas'] as int?) ?? 0,
    );
  }
}
