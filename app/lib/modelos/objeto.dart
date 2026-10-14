/// Una pieza del museo, con lo justo para elegirla al armar un desafío.
///
/// La administración de objetos todavía vive en el panel web; acá sólo hace
/// falta poder señalar cuál es, así que no se traen la descripción, la imagen
/// ni el resto de los datos.
class Objeto {
  final int id;
  final String nombre;
  final String codigo;

  /// Un objeto dado de baja no se puede elegir para un desafío nuevo, pero
  /// sigue apareciendo en la lista porque puede haber desafíos viejos que lo
  /// usen y hay que poder abrirlos sin perder cuál era.
  final bool activo;

  /// Sala donde está la pieza, para distinguir dos con nombres parecidos.
  final String? sala;

  const Objeto({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.activo,
    required this.sala,
  });

  /// Lo que se lee en el selector.
  String get etiqueta => activo ? nombre : '$nombre — dado de baja';

  factory Objeto.desdeJson(Map<String, dynamic> json) {
    return Objeto(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: (json['codigo'] as String?) ?? '',
      activo: (json['activo'] as bool?) ?? true,
      sala: json['sala'] as String?,
    );
  }
}
