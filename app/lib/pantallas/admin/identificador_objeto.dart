import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/objeto.dart';
import '../../widgets/formulario.dart';

/// El identificador de una pieza: su código y, si se identifica con QR, el
/// código dibujado para imprimir y pegar en la vitrina.
///
/// El QR contiene el código tal cual (OBJ-XXXXXXXX) y no una dirección web. Es
/// a propósito: si llevara una dirección, el día que cambie el dominio todas
/// las etiquetas ya impresas quedarían inservibles.
class IdentificadorObjeto extends StatefulWidget {
  final Objeto objeto;

  /// Pide a la API un código nuevo y devuelve la pieza actualizada.
  final Future<Objeto> Function() alRegenerar;

  const IdentificadorObjeto({
    super.key,
    required this.objeto,
    required this.alRegenerar,
  });

  @override
  State<IdentificadorObjeto> createState() => _IdentificadorObjetoState();
}

class _IdentificadorObjetoState extends State<IdentificadorObjeto> {
  bool _regenerando = false;
  bool _compartiendo = false;
  String _error = '';

  bool get _esQr => widget.objeto.tipoIdentificador == TipoIdentificador.qr;

  Future<void> _compartir() async {
    setState(() {
      _compartiendo = true;
      _error = '';
    });
    try {
      final imagen = await _dibujarEtiqueta(widget.objeto);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            // Sin ruta en disco: share_plus la escribe solo en una carpeta
            // temporal antes de pasársela a Android.
            XFile.fromData(
              imagen,
              mimeType: 'image/png',
              name: '${widget.objeto.codigo}.png',
            ),
          ],
          text: '${widget.objeto.nombre} — ${widget.objeto.codigo}',
        ),
      );
    } catch (error, pila) {
      debugPrint('Fallo al compartir la etiqueta: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo preparar la etiqueta.');
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  Future<void> _regenerar() async {
    final confirmado = await _confirmarRegenerado();
    if (confirmado != true || !mounted) return;

    setState(() {
      _regenerando = true;
      _error = '';
    });
    try {
      await widget.alRegenerar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código nuevo generado. Reemplazá la etiqueta de la pieza.')),
      );
    } on ErrorApi catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al regenerar el código: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo generar un código nuevo.');
    } finally {
      if (mounted) setState(() => _regenerando = false);
    }
  }

  /// Se pregunta antes porque la consecuencia no es obvia: el código viejo deja
  /// de servir y la etiqueta ya pegada junto a la pieza queda inservible.
  Future<bool?> _confirmarRegenerado() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Generar un código nuevo?', style: AppText.serif(size: 19)),
        content: Text(
          'La etiqueta que ya está puesta junto a la pieza deja de funcionar y '
          'hay que reemplazarla por una nueva.\n\n'
          'Los desafíos que usan esta pieza siguen funcionando: apuntan al objeto, '
          'no al código.',
          style: AppText.sans(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: AppText.sans(size: 14, peso: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sí, generar uno nuevo',
              style: AppText.sans(size: 14, color: AppColors.dificil, peso: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final objeto = widget.objeto;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _esQr ? 'Código QR de la pieza' : 'Etiqueta NFC de la pieza',
            style: AppText.sans(size: 13.5, peso: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          if (_esQr) ...[
            // Fondo blanco siempre: un QR sobre fondo oscuro no lo lee
            // ninguna cámara, y además es como se va a imprimir.
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: objeto.codigo,
                  version: QrVersions.auto,
                  size: 180,
                  gapless: true,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Center(
            child: Text(
              objeto.codigo,
              style: AppText.sans(size: 18, color: AppColors.textoPrimario).copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            _esQr
                ? 'Imprimí esta etiqueta y pegala junto a la pieza. El QR contiene el '
                    'código, que es lo que la app compara al escanear.'
                : 'Grabá este código en la etiqueta NFC con una app de escritura NFC, '
                    'apoyando el teléfono sobre la etiqueta.',
            style: AppText.sans(size: 13),
          ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Aviso(_error),
          ],

          if (_esQr) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _compartiendo ? null : _compartir,
                icon: Icon(
                  Icons.ios_share,
                  size: 18,
                  color: _compartiendo ? AppColors.textoInactivo : AppColors.acento,
                ),
                label: Text(
                  _compartiendo ? 'Preparando…' : 'Compartir etiqueta',
                  style: AppText.sans(
                    size: 14.5,
                    color: _compartiendo ? AppColors.textoInactivo : AppColors.acento,
                    peso: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: _compartiendo ? AppColors.borde : AppColors.acento,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _regenerando ? null : _regenerar,
              icon: Icon(
                Icons.autorenew,
                size: 18,
                color: _regenerando ? AppColors.textoInactivo : AppColors.dificil,
              ),
              label: Text(
                _regenerando ? 'Generando…' : 'Generar un código nuevo',
                style: AppText.sans(
                  size: 13.5,
                  color: _regenerando ? AppColors.textoInactivo : AppColors.dificil,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja la etiqueta lista para imprimir: el QR, el nombre de la pieza y el
/// código, todo en una sola imagen.
///
/// Se comparte la etiqueta entera y no el QR solo porque un QR pelado, una vez
/// impreso, no dice de qué pieza es.
///
/// El texto va con la tipografía por defecto del sistema y no con la de la app:
/// esto es una imagen para imprimir, no una pantalla, y conviene que no dependa
/// de que una fuente esté descargada.
Future<Uint8List> _dibujarEtiqueta(Objeto objeto) async {
  const lado = 560.0; // lado del QR, grande para que imprima nítido
  const margen = 56.0;
  const separacion = 28.0;

  final nombre = _texto(
    objeto.nombre,
    const TextStyle(color: Color(0xFF111111), fontSize: 38, fontWeight: FontWeight.w700),
    lado,
  );
  final codigo = _texto(
    objeto.codigo,
    const TextStyle(
      color: Color(0xFF444444),
      fontSize: 34,
      fontFamily: 'monospace',
      letterSpacing: 2,
    ),
    lado,
  );

  const ancho = lado + margen * 2;
  final alto = margen + lado + separacion + nombre.height + 12 + codigo.height + margen;

  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora, Rect.fromLTWH(0, 0, ancho, alto));

  // Fondo blanco: es una etiqueta para imprimir.
  lienzo.drawRect(
    Rect.fromLTWH(0, 0, ancho, alto),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  final pintorQr = QrPainter(
    data: objeto.codigo,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Color(0xFF000000),
    ),
  );
  lienzo.save();
  lienzo.translate(margen, margen);
  pintorQr.paint(lienzo, const Size(lado, lado));
  lienzo.restore();

  var y = margen + lado + separacion;
  nombre.paint(lienzo, Offset(margen + (lado - nombre.width) / 2, y));
  y += nombre.height + 12;
  codigo.paint(lienzo, Offset(margen + (lado - codigo.width) / 2, y));

  final imagen = await grabadora.endRecording().toImage(ancho.round(), alto.round());
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  if (datos == null) throw StateError('No se pudo convertir la etiqueta a PNG');
  return datos.buffer.asUint8List();
}

TextPainter _texto(String texto, TextStyle estilo, double anchoMaximo) {
  final pintor = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: anchoMaximo);
  return pintor;
}
