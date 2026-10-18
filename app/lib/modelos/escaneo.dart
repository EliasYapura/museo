/// Lo que contesta el servidor cuando se le manda un código escaneado (VIS05).
///
/// La comparación del código contra la pieza esperada la hace el servidor
/// (SIS01), así que la app no sabe cuál era el código correcto: sólo si el que
/// mandó servía.
class ResultadoEscaneo {
  /// Si el código escaneado es el de la pieza que pide este desafío.
  final bool correcto;

  /// Nombre de la pieza. Llega recién ahora en la búsqueda guiada, donde
  /// hasta el escaneo el servidor no lo manda.
  final String? pieza;

  /// Lo que el museo cuenta de la pieza al encontrarla. Es la recompensa por
  /// llegar hasta la vitrina y, cuando el desafío tiene pregunta, la
  /// información con la que se responde.
  final String? datoClave;

  /// Si el desafío queda terminado con el escaneo. Pasa en los de escaneo y
  /// búsqueda guiada, que no tienen nada que contestar.
  final bool resuelto;

  /// Los puntos que sumó. Es 0 mientras el desafío siga teniendo una pregunta
  /// pendiente: esos puntos llegan al responderla (VIS06, VIS08).
  final int puntos;

  const ResultadoEscaneo({
    required this.correcto,
    required this.pieza,
    required this.datoClave,
    required this.resuelto,
    required this.puntos,
  });

  factory ResultadoEscaneo.desdeJson(Map<String, dynamic> json) {
    return ResultadoEscaneo(
      correcto: json['correcto'] as bool? ?? false,
      pieza: json['pieza'] as String?,
      datoClave: json['dato_clave'] as String?,
      resuelto: json['resuelto'] as bool? ?? false,
      puntos: json['puntos'] as int? ?? 0,
    );
  }
}
