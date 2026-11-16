import 'package:flutter/material.dart';

import '../estilo.dart';
import '../modelos/mision.dart';

/// La imagen de una misión en la app del visitante (ADM25).
///
/// Si el museo le cargó una portada, se muestra. Si no, se dibuja el ícono
/// temático que le toca por el id, que es lo que se veía antes de que las
/// misiones pudieran tener imagen. Lo mismo mientras la portada viaja y si la
/// dirección no carga: nunca queda un hueco donde iba la imagen.
///
/// Está en un widget compartido porque la misma portada aparece en el listado
/// y en el detalle, con distinto tamaño pero con las mismas reglas.
class PortadaMision extends StatelessWidget {
  final Mision mision;

  /// El lado del cuadrado.
  final double lado;

  final double radio;

  /// El color de atrás, que es el que se ve detrás del ícono temático.
  final Color fondo;

  /// El borde, o null si no lleva.
  final Color? borde;

  const PortadaMision({
    super.key,
    required this.mision,
    required this.lado,
    this.radio = 12,
    this.fondo = AppColors.fondo,
    this.borde,
  });

  @override
  Widget build(BuildContext context) {
    final url = mision.imagenUrl;

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(radio),
        border: borde == null ? null : Border.all(color: borde!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: url == null || url.isEmpty ? _icono() : _imagen(url),
      ),
    );
  }

  Widget _imagen(String url) {
    return Image.network(
      url,
      width: lado,
      height: lado,
      fit: BoxFit.cover,
      // Sin etiqueta el lector de pantalla anuncia "imagen" y nada más. Lo
      // útil no es describir la foto —no sabemos qué tiene— sino decir de qué
      // misión es, que es lo que la ubica en la pantalla.
      semanticLabel: 'Imagen de la misión ${mision.nombre}',
      // Mientras viaja se muestra el ícono temático y no una rueda girando: en
      // un listado, media docena de ruedas se lee como que algo anda mal.
      loadingBuilder: (context, hijo, progreso) => progreso == null ? hijo : _icono(),
      // El motivo del fallo queda en el log: tapado a la vista, que es lo
      // correcto para quien usa la app, la pantalla no tendría forma de
      // distinguir "no carga" de "no tiene portada".
      errorBuilder: (context, error, pila) {
        debugPrint('No se pudo cargar la portada $url: $error');
        return _icono();
      },
    );
  }

  Widget _icono() => CustomPaint(painter: IconoPainter(mision.icono));
}
