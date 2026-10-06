import 'package:flutter/material.dart';

import '../estilo.dart';

/// Los tres valores del enum dificultad_mision de la base.
enum Dificultad { facil, media, dificil }

extension DificultadX on Dificultad {
  String get etiqueta => switch (this) {
        Dificultad.facil => 'Fácil',
        Dificultad.media => 'Media',
        Dificultad.dificil => 'Difícil',
      };

  Color get color => switch (this) {
        Dificultad.facil => AppColors.facil,
        Dificultad.media => AppColors.media,
        Dificultad.dificil => AppColors.dificil,
      };
}

/// Una misión publicada, tal como la devuelve GET /publico/misiones (VIS01).
class Mision {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final Dificultad dificultad;
  final int duracionMin;
  final int desafios;
  final int puntos;

  /// Sala donde empieza el recorrido. La API la deduce del primer desafío que
  /// tenga un objeto asociado, así que puede no venir.
  final String? sala;

  /// Todas las salas por las que pasa la misión, en el orden del recorrido del
  /// museo. Solo viene en el detalle (VIS03); en el listado llega vacía.
  final List<String> salas;

  const Mision({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.imagenUrl,
    required this.dificultad,
    required this.duracionMin,
    required this.desafios,
    required this.puntos,
    required this.sala,
    this.salas = const [],
  });

  /// Mientras las misiones no tengan imagen, la miniatura se elige por el id:
  /// siempre el mismo ícono para la misma misión, en vez de uno al azar que
  /// cambie en cada recarga.
  IconoMision get icono => IconoMision.values[id % IconoMision.values.length];

  /// Lo que se lee abajo del nombre en la tarjeta.
  String get subtitulo => sala ?? descripcion;

  factory Mision.desdeJson(Map<String, dynamic> json) {
    return Mision(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      imagenUrl: json['imagen_url'] as String?,
      // Un valor desconocido no tira la pantalla abajo: se muestra como media.
      dificultad: Dificultad.values.firstWhere(
        (d) => d.name == json['dificultad'],
        orElse: () => Dificultad.media,
      ),
      duracionMin: json['duracion_estimada'] as int,
      desafios: json['desafios'] as int,
      puntos: json['puntos'] as int,
      sala: json['sala'] as String?,
      // El listado no manda salas; el detalle si.
      salas: ((json['salas'] as List?) ?? const []).map((s) => s as String).toList(),
    );
  }
}
