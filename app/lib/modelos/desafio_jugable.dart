import 'desafio.dart';

/// Un desafío tal como lo ve el visitante durante el recorrido (VIS04).
///
/// No es el mismo [Desafio] que usa la administración, aunque compartan el
/// tipo: acá no están la respuesta correcta ni cómo se compara, porque esos
/// datos no salen del servidor. Si viajaran hasta el teléfono, cualquiera
/// podría abrir el APK y leer las respuestas de todas las misiones.
class DesafioJugable {
  final int id;

  /// Posición dentro de la misión, tal como la numeró el administrador.
  final int orden;

  /// Null cuando la API devuelve un tipo que esta versión de la app todavía no
  /// conoce. El enunciado se muestra igual.
  final TipoDesafio? tipo;

  /// El tipo tal como llegó, para no perder el dato cuando [tipo] es null.
  final String tipoCrudo;

  final String enunciado;

  /// Lo que suma al resolverlo (VIS08).
  final int puntos;

  /// Las opciones de una pregunta de opción múltiple; vacío en los demás tipos.
  final List<String> opciones;

  /// Si hay una pieza con código junto a ella que el visitante tiene que
  /// encontrar y escanear antes de resolver el desafío (VIS05).
  final bool requiereEscaneo;

  /// Nombre de la pieza. Es null cuando el desafío no tiene ninguna asociada y
  /// también en la búsqueda guiada: ahí el servidor lo oculta a propósito,
  /// porque encontrarla es el desafío.
  final String? pieza;

  /// Sala donde está la pieza. Null si el desafío no tiene pieza.
  final String? sala;

  /// Lo que cuesta cada pista, en el orden en que se entregan (VIS07).
  ///
  /// Los textos no están acá: se piden de a uno, cuando el visitante decide
  /// pagar. Lo que sí viaja es el precio, porque hay que poder mostrárselo
  /// antes de cobrárselo.
  final List<int> penalizaciones;

  const DesafioJugable({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.tipoCrudo,
    required this.enunciado,
    required this.puntos,
    required this.opciones,
    required this.requiereEscaneo,
    required this.pieza,
    required this.sala,
    required this.penalizaciones,
  });

  /// Si el administrador le cargó alguna pista (ADM13).
  bool get tienePistas => penalizaciones.isNotEmpty;

  /// Cuánto vale el desafío después de pedir [usadas] pistas.
  ///
  /// Es sólo para mostrarlo: los puntos que se otorgan los calcula el
  /// servidor, con esta misma cuenta, al comprobar la respuesta o el código.
  /// Acá se repite para poder avisarle al visitante qué le va a quedar antes
  /// de que resuelva, no para decidirlo.
  int valeCon(int usadas) {
    final descuento = penalizaciones.take(usadas).fold(0, (suma, costo) => suma + costo);
    return puntos - descuento < 0 ? 0 : puntos - descuento;
  }

  /// Si además de encontrar la pieza hay algo que contestar (VIS06). Los
  /// desafíos de escaneo y de búsqueda se resuelven llegando a la pieza.
  bool get tienePregunta =>
      tipo == TipoDesafio.preguntaOpcionMultiple || tipo == TipoDesafio.respuestaCorta;

  factory DesafioJugable.desdeJson(Map<String, dynamic> json) {
    return DesafioJugable(
      id: json['id'] as int,
      orden: json['orden'] as int,
      tipo: TipoDesafioX.desdeApi(json['tipo'] as String?),
      tipoCrudo: (json['tipo'] as String?) ?? '',
      enunciado: json['enunciado'] as String,
      puntos: json['puntos'] as int,
      opciones: ((json['opciones'] as List?) ?? const []).whereType<String>().toList(),
      requiereEscaneo: json['requiere_escaneo'] as bool? ?? false,
      pieza: json['pieza'] as String?,
      sala: json['sala'] as String?,
      // Viene como "pistas" porque es lo que la API manda de las pistas: no
      // cuántas hay, sino lo que cuesta cada una.
      penalizaciones: ((json['pistas'] as List?) ?? const []).whereType<int>().toList(),
    );
  }
}
