/// Los cuatro valores del enum tipo_desafio de la base.
///
/// Es un enum y no el texto suelto que manda la API para que el compilador
/// avise si falta contemplar un tipo en algún lado, en vez de que la pantalla
/// muestre un caso sin resolver recién cuando el administrador lo abra.
enum TipoDesafio { preguntaOpcionMultiple, respuestaCorta, escaneoObjeto, busquedaGuiada }

extension TipoDesafioX on TipoDesafio {
  /// El valor tal como lo guarda y lo espera la API.
  String get valorApi => switch (this) {
        TipoDesafio.preguntaOpcionMultiple => 'pregunta_opcion_multiple',
        TipoDesafio.respuestaCorta => 'respuesta_corta',
        TipoDesafio.escaneoObjeto => 'escaneo_objeto',
        TipoDesafio.busquedaGuiada => 'busqueda_guiada',
      };

  String get etiqueta => switch (this) {
        TipoDesafio.preguntaOpcionMultiple => 'Pregunta de opción múltiple',
        TipoDesafio.respuestaCorta => 'Respuesta corta',
        TipoDesafio.escaneoObjeto => 'Escaneo de objeto',
        TipoDesafio.busquedaGuiada => 'Búsqueda guiada',
      };

  /// Estos dos mandan al visitante a una pieza concreta del museo, así que no
  /// tienen sentido sin un objeto asociado. La API los rechaza sin él.
  bool get necesitaObjeto =>
      this == TipoDesafio.escaneoObjeto || this == TipoDesafio.busquedaGuiada;

  static TipoDesafio? desdeApi(String? valor) {
    for (final tipo in TipoDesafio.values) {
      if (tipo.valorApi == valor) return tipo;
    }
    return null;
  }
}

/// Un desafío de una misión, visto desde la administración.
class Desafio {
  final int id;
  final int misionId;

  /// Posición dentro de la misión: es el orden en que los resuelve el
  /// visitante.
  final int orden;

  /// Null cuando la API devuelve un tipo que esta versión de la app todavía no
  /// conoce. Se muestra igual, sin romper el listado.
  final TipoDesafio? tipo;

  /// El tipo tal como llegó. Sirve para mostrar algo cuando [tipo] es null.
  final String tipoCrudo;

  final String enunciado;
  final int puntos;

  /// Nombre de la pieza del museo asociada, si tiene.
  final String? objeto;
  final int? objetoId;

  /// Lo propio de cada tipo: las opciones de una pregunta, la tolerancia de
  /// una respuesta corta. Los otros tipos no guardan nada.
  final Map<String, dynamic> configuracion;

  /// Null en los tipos que se resuelven encontrando la pieza.
  final String? respuestaCorrecta;

  const Desafio({
    required this.id,
    required this.misionId,
    required this.orden,
    required this.tipo,
    required this.tipoCrudo,
    required this.enunciado,
    required this.puntos,
    required this.objeto,
    required this.objetoId,
    required this.configuracion,
    required this.respuestaCorrecta,
  });

  /// Nombre del tipo para mostrar. Si la API mandó uno desconocido se muestra
  /// tal cual vino, que dice más que un "—".
  String get nombreDelTipo => tipo?.etiqueta ?? tipoCrudo;

  /// Las opciones de una pregunta de opción múltiple; vacío en los demás tipos.
  List<String> get opciones {
    final valor = configuracion['opciones'];
    if (valor is! List) return const [];
    return valor.whereType<String>().toList();
  }

  /// 'exacta' o 'flexible' en una respuesta corta; null en los demás tipos.
  String? get tolerancia => configuracion['tolerancia'] as String?;

  /// Lo propio del tipo, resumido para la tarjeta del listado, así no hay que
  /// abrir cada desafío para saber cómo está armado.
  String? get resumen {
    if (tipo == TipoDesafio.preguntaOpcionMultiple && opciones.isNotEmpty) {
      return '${opciones.length} opciones';
    }
    if (tipo == TipoDesafio.respuestaCorta && tolerancia != null) {
      return tolerancia == 'exacta' ? 'comparación exacta' : 'comparación flexible';
    }
    return null;
  }

  factory Desafio.desdeJson(Map<String, dynamic> json) {
    return Desafio(
      id: json['id'] as int,
      misionId: json['mision_id'] as int,
      orden: json['orden'] as int,
      tipo: TipoDesafioX.desdeApi(json['tipo'] as String?),
      tipoCrudo: (json['tipo'] as String?) ?? '',
      enunciado: json['enunciado'] as String,
      puntos: json['puntos'] as int,
      objeto: json['objeto'] as String?,
      objetoId: json['objeto_id'] as int?,
      configuracion: (json['configuracion'] as Map?)?.cast<String, dynamic>() ?? const {},
      respuestaCorrecta: json['respuesta_correcta'] as String?,
    );
  }
}
