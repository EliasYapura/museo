import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../sesion/sesion.dart';
import 'formulario.dart';

/// El campo para cargar una imagen desde el teléfono (ADM25).
///
/// Lo usan los tres formularios que tienen imagen —insignia, misión y pieza—
/// con la misma mecánica: se elige de la galería y se sube en el momento, sin
/// esperar al botón de guardar.
///
/// Se sube enseguida porque es un pedido distinto del de guardar: el
/// formulario cambia el nombre y la descripción, y la imagen va por su propia
/// ruta en la API. Mezclarlas obligaría a deshacer una si fallara la otra.
///
/// El widget se ocupa de la galería, de leer los bytes, del cartel de
/// "subiendo" y de los errores. Quién sube y a dónde lo deciden [alSubir] y
/// [alQuitar], que son los que llaman a la API y devuelven la dirección que
/// quedó guardada.
class CampoDeImagen extends StatefulWidget {
  /// La dirección que tiene puesta ahora, o null si no tiene ninguna.
  final String? url;

  /// Dibuja la imagen como se va a ver en la app. Recibe la dirección actual,
  /// que puede ser null.
  final Widget Function(String? url) vistaPrevia;

  /// true si la vista previa ocupa todo el ancho (una portada), false si es
  /// chica y va al lado del texto (el ícono de una insignia).
  final bool vistaPreviaAncha;

  /// Sube la imagen y devuelve la dirección que quedó guardada.
  final Future<String?> Function(List<int> bytes, String tipo) alSubir;

  /// Le saca la imagen y devuelve la dirección que quedó (normalmente null).
  final Future<String?> Function() alQuitar;

  /// Avisa al formulario la dirección nueva, para que la guarde en su estado.
  final ValueChanged<String?> alCambiar;

  /// Qué se lee al lado de la vista previa cuando no hay imagen cargada.
  final String ayudaSinImagen;

  /// El campo con el que la API informa el error de esta imagen: 'icono' en
  /// las insignias, 'imagen' en las misiones y las piezas.
  final String campoDeError;

  /// El lado máximo al que se encoge la foto antes de subirla. Una foto de 12
  /// megapíxeles no se ve mejor en un recuadro de la app y tarda en subir.
  final int ladoMaximo;

  /// Mientras el formulario está guardando, los botones van apagados.
  final bool deshabilitado;

  const CampoDeImagen({
    super.key,
    required this.url,
    required this.vistaPrevia,
    required this.alSubir,
    required this.alQuitar,
    required this.alCambiar,
    required this.ayudaSinImagen,
    required this.campoDeError,
    this.vistaPreviaAncha = false,
    this.ladoMaximo = 1280,
    this.deshabilitado = false,
  });

  @override
  State<CampoDeImagen> createState() => _CampoDeImagenState();
}

class _CampoDeImagenState extends State<CampoDeImagen> {
  bool _trabajando = false;
  String _error = '';

  bool get _tiene => widget.url != null && widget.url!.isNotEmpty;
  bool get _ocupado => _trabajando || widget.deshabilitado;

  @override
  Widget build(BuildContext context) {
    final leyenda = _trabajando
        ? 'Subiendo…'
        : _tiene
            ? 'Así se va a ver en la app.'
            : widget.ayudaSinImagen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.vistaPreviaAncha) ...[
          // La clave hace que Flutter rearme la imagen cuando cambia la
          // dirección. Sin ella reutiliza la anterior, que es justo lo que no
          // se quiere al reemplazarla.
          KeyedSubtree(key: ValueKey(widget.url), child: widget.vistaPrevia(widget.url)),
          const SizedBox(height: 10),
          Text(leyenda, style: AppText.sans(size: 13)),
        ] else
          Row(
            children: [
              KeyedSubtree(key: ValueKey(widget.url), child: widget.vistaPrevia(widget.url)),
              const SizedBox(width: 14),
              Expanded(child: Text(leyenda, style: AppText.sans(size: 13))),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _elegir,
              icon: Icon(
                Icons.image_outlined,
                size: 18,
                color: _ocupado ? AppColors.textoInactivo : AppColors.acento,
              ),
              label: Text(
                _tiene ? 'Cambiar imagen' : 'Elegir imagen',
                style: AppText.sans(
                  size: 13.5,
                  color: _ocupado ? AppColors.textoInactivo : AppColors.acento,
                  peso: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _ocupado ? AppColors.borde : AppColors.acento),
              ),
            ),
            if (_tiene) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _ocupado ? null : _quitar,
                child: Text(
                  'Quitar',
                  style: AppText.sans(
                    size: 13.5,
                    color: _ocupado ? AppColors.textoInactivo : AppColors.error,
                    peso: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Aviso(_error),
        ],
        const SizedBox(height: 4),
        Text(
          'PNG, JPEG o WebP, hasta 2 MB. Se guarda apenas la elegís, sin '
          'esperar al botón de guardar.',
          style: AppText.sans(size: 12.5),
        ),
      ],
    );
  }

  Future<void> _elegir() async {
    final XFile? elegida;
    try {
      elegida = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: widget.ladoMaximo.toDouble(),
        maxHeight: widget.ladoMaximo.toDouble(),
      );
    } catch (error, pila) {
      debugPrint('Fallo al abrir la galería: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo abrir la galería.');
      return;
    }
    if (elegida == null || !mounted) return;

    final bytes = await elegida.readAsBytes();
    // El tipo sale de la extensión, pero es sólo para la cabecera: el servidor
    // lo reconoce mirando los primeros bytes y rechaza lo que no sea una
    // imagen, diga lo que diga este dato.
    final tipo = switch (elegida.path.toLowerCase().split('.').last) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _conLaApi(() => widget.alSubir(bytes, tipo), 'No se pudo subir la imagen.');
  }

  Future<void> _quitar() => _conLaApi(widget.alQuitar, 'No se pudo quitar la imagen.');

  /// Lo que rodea a cualquiera de los dos pedidos: el cartel de "subiendo", el
  /// aviso al formulario con la dirección nueva y el reparto de errores.
  Future<void> _conLaApi(Future<String?> Function() pedido, String mensajeGenerico) async {
    final sesion = ProveedorSesion.de(context);
    setState(() {
      _trabajando = true;
      _error = '';
    });
    try {
      final url = await pedido();
      if (!mounted) return;
      widget.alCambiar(url);
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        return;
      }
      setState(() => _error = error.errores[widget.campoDeError] ?? error.mensaje);
    } catch (error, pila) {
      debugPrint('$mensajeGenerico $error\n$pila');
      if (mounted) setState(() => _error = mensajeGenerico);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }
}

/// La vista previa de una portada: el recuadro apaisado que se usa en el
/// formulario de una misión y en el de una pieza.
///
/// Sin imagen no queda un hueco: se dibuja el recuadro con un ícono, para que
/// se vea que el lugar existe y está vacío.
class VistaPreviaPortada extends StatelessWidget {
  final String? url;

  /// Lo que anuncia el lector de pantalla. Describir la foto no sirve —la
  /// carga quien la está mirando—; lo útil es decir de qué imagen se trata.
  final String etiqueta;

  final double altura;

  const VistaPreviaPortada({
    super.key,
    required this.url,
    required this.etiqueta,
    this.altura = 160,
  });

  @override
  Widget build(BuildContext context) {
    final direccion = url;
    if (direccion == null || direccion.isEmpty) return _vacio(Icons.image_outlined);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        direccion,
        semanticLabel: etiqueta,
        height: altura,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, hijo, progreso) => progreso == null
            ? hijo
            : Container(
                height: altura,
                color: AppColors.superficie,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppColors.acento),
              ),
        // Que una dirección no cargue es lo más común con imágenes de
        // internet. El motivo queda en el log: sin eso, la pantalla no
        // distingue "no carga" de "no tiene imagen".
        errorBuilder: (context, error, pila) {
          debugPrint('No se pudo cargar la imagen $direccion: $error');
          return _vacio(Icons.broken_image_outlined);
        },
      ),
    );
  }

  Widget _vacio(IconData icono) {
    return Container(
      height: altura,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      alignment: Alignment.center,
      child: Icon(icono, size: 34, color: AppColors.textoInactivo),
    );
  }
}
