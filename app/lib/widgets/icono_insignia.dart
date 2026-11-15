import 'package:flutter/material.dart';

import '../estilo.dart';

/// El ícono de una insignia (ADM25).
///
/// Si el museo le cargó una imagen, se muestra. Si no la cargó, si la
/// dirección no carga o mientras está cargando, se dibuja el hexágono
/// genérico. Nunca queda un hueco: la insignia es redonda y chica, y un vacío
/// ahí se ve como un error de la app.
///
/// Está en un widget compartido porque la misma insignia aparece en cuatro
/// lugares —el listado de administración, su ficha, la pestaña del visitante y
/// el recuadro del resultado— y antes cada uno dibujaba su propio hexágono.
class IconoInsignia extends StatelessWidget {
  final String? url;

  /// El diámetro del círculo.
  final double tamanio;

  /// Si el visitante ya la ganó. Las que le faltan se ven apagadas: en gris y
  /// a media opacidad si tienen imagen, con el hexágono hueco si no.
  ///
  /// Desde la administración no hay "ganada" que valga, así que se pasa true y
  /// se ven siempre a color.
  final bool ganada;

  const IconoInsignia({
    super.key,
    required this.url,
    this.tamanio = 46,
    this.ganada = true,
  });

  @override
  Widget build(BuildContext context) {
    final direccion = url;
    final borde = ganada ? AppColors.acento : AppColors.borde;

    return Container(
      width: tamanio,
      height: tamanio,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fondo,
        shape: BoxShape.circle,
        border: Border.all(color: borde),
      ),
      child: ClipOval(
        child: direccion == null || direccion.isEmpty
            ? _hexagono()
            : _imagen(direccion),
      ),
    );
  }

  Widget _imagen(String direccion) {
    final imagen = Image.network(
      direccion,
      width: tamanio,
      height: tamanio,
      fit: BoxFit.cover,
      // Mientras viaja se muestra el hexágono, no un indicador de carga: en una
      // lista de insignias, media docena de ruedas girando se lee como que algo
      // anda mal.
      loadingBuilder: (context, hijo, progreso) => progreso == null ? hijo : _hexagono(),
      // Una dirección que no carga es lo más común con imágenes de internet.
      // Se cae al hexágono en vez de dejar el ícono roto de Flutter.
      // El hexágono tapa el fallo a la vista, que es lo correcto para quien
      // usa la app, pero deja la pantalla sin forma de distinguir "no carga"
      // de "no tiene imagen". Por eso el motivo queda en el log.
      errorBuilder: (context, error, pila) {
        debugPrint('No se pudo cargar el ícono $direccion: $error');
        return _hexagono();
      },
    );

    if (ganada) return imagen;

    // Las que faltan van en gris y atenuadas. A todo color se perdería la
    // diferencia entre lo ganado y lo que falta, que es lo que hace que la
    // pestaña de insignias sirva para algo.
    return Opacity(
      opacity: 0.45,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: imagen,
      ),
    );
  }

  Widget _hexagono() {
    return Icon(
      ganada ? Icons.hexagon : Icons.hexagon_outlined,
      size: tamanio * 0.48,
      color: ganada ? AppColors.acento : AppColors.textoInactivo,
    );
  }
}
