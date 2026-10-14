/// Una sala del museo.
///
/// Las salas se cargan en la base y no se administran desde ningún lado: acá
/// sólo hacen falta para elegir dónde está una pieza.
class Sala {
  final int id;
  final String nombre;

  /// Piso o nivel del edificio donde está la sala, si está cargado.
  final String? nivel;

  const Sala({required this.id, required this.nombre, required this.nivel});

  factory Sala.desdeJson(Map<String, dynamic> json) {
    return Sala(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      nivel: json['nivel'] as String?,
    );
  }
}
