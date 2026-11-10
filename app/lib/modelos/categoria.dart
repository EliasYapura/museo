/// Una categoría con la que se clasifican las piezas del museo (ADM23).
///
/// Son del museo y no se administran desde la app, igual que las salas: se
/// cargan en la base. Acá sólo hacen falta para clasificar una pieza y para
/// filtrar el listado.
class Categoria {
  final int id;
  final String nombre;

  /// Cuántas piezas tiene clasificadas. Sirve para no ofrecer en el filtro
  /// categorías que no van a devolver nada.
  final int objetos;

  const Categoria({required this.id, required this.nombre, required this.objetos});

  factory Categoria.desdeJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      objetos: (json['objetos'] as int?) ?? 0,
    );
  }
}
