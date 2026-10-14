/// Cómo se identifica una pieza cuando el visitante llega hasta ella.
///
/// Son los dos valores del enum tipo_identificador de la base.
enum TipoIdentificador { qr, nfc }

extension TipoIdentificadorX on TipoIdentificador {
  /// El valor tal como lo guarda y lo espera la API.
  String get valorApi => name;

  String get etiqueta => switch (this) {
        TipoIdentificador.qr => 'QR',
        TipoIdentificador.nfc => 'NFC',
      };

  static TipoIdentificador desdeApi(String? valor) {
    return valor == 'nfc' ? TipoIdentificador.nfc : TipoIdentificador.qr;
  }
}

/// Una pieza del museo.
///
/// Es el mismo modelo que usa el selector de objetos de un desafío, que sólo
/// mira el nombre y si está activa. Los demás campos vienen en la misma
/// respuesta de `GET /objetos`, así que tener un modelo aparte sólo para el
/// selector sería repetir lo mismo dos veces.
class Objeto {
  final int id;
  final String nombre;

  /// El código pegado en la vitrina: OBJ-XXXXXXXX. Es lo que el visitante
  /// escanea y lo que la app compara contra la pieza.
  final String codigo;

  final TipoIdentificador tipoIdentificador;

  /// Un objeto dado de baja no se elige para un desafío nuevo, pero sigue
  /// apareciendo en la lista porque puede haber desafíos viejos que lo usen y
  /// hay que poder encontrarlo para reactivarlo.
  final bool activo;

  /// Sala donde está la pieza, para distinguir dos con nombres parecidos.
  final String? sala;
  final int? salaId;

  /// El dato que el museo quiere que el visitante se lleve de esta pieza.
  final String datoClave;

  final String descripcion;
  final String? imagenUrl;

  /// En cuántos desafíos se usa. Mientras sea mayor que cero la pieza no se
  /// puede borrar, sólo dar de baja.
  final int desafios;

  const Objeto({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.tipoIdentificador,
    required this.activo,
    required this.sala,
    required this.salaId,
    required this.datoClave,
    required this.descripcion,
    required this.imagenUrl,
    required this.desafios,
  });

  /// Lo que se lee en el selector de objetos de un desafío.
  String get etiqueta => activo ? nombre : '$nombre — dado de baja';

  factory Objeto.desdeJson(Map<String, dynamic> json) {
    return Objeto(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: (json['codigo'] as String?) ?? '',
      tipoIdentificador: TipoIdentificadorX.desdeApi(json['tipo_identificador'] as String?),
      activo: (json['activo'] as bool?) ?? true,
      sala: json['sala'] as String?,
      salaId: json['sala_id'] as int?,
      datoClave: (json['dato_clave'] as String?) ?? '',
      descripcion: (json['descripcion'] as String?) ?? '',
      imagenUrl: json['imagen_url'] as String?,
      desafios: (json['desafios'] as int?) ?? 0,
    );
  }
}
