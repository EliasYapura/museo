/// Una pista de un desafío, vista desde la administración (ADM13).
///
/// Es la ayuda que el visitante puede pedir cuando no le sale un desafío, a
/// cambio de perder puntos. Desde la administración se ve completa; al
/// visitante se le entrega de a una y recién cuando la pide (VIS07).
class Pista {
  final int id;
  final int desafioId;

  /// En qué lugar se entrega. La asigna la API al crearla, siempre al final, y
  /// no se edita: la restricción de la base no permite renumerarlas.
  ///
  /// Puede tener huecos. Al borrar la segunda de tres quedan la 1 y la 3, y la
  /// siguiente que se cargue será la 4. Para mostrarlas se usa la posición en
  /// la lista, igual que con los desafíos de una misión.
  final int orden;

  final String texto;

  /// Puntos que se le descuentan al visitante por pedirla. Puede ser 0.
  final int penalizacion;

  const Pista({
    required this.id,
    required this.desafioId,
    required this.orden,
    required this.texto,
    required this.penalizacion,
  });

  factory Pista.desdeJson(Map<String, dynamic> json) {
    return Pista(
      id: json['id'] as int,
      desafioId: json['desafio_id'] as int,
      orden: json['orden'] as int,
      texto: json['texto'] as String,
      penalizacion: json['penalizacion'] as int,
    );
  }
}
