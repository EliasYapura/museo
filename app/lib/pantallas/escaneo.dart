import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/desafio_jugable.dart';
import '../modelos/escaneo.dart';

/// Lee el código QR que está junto a una pieza del museo (VIS05).
///
/// Si el código es el que el desafío espera, devuelve el [ResultadoEscaneo] al
/// recorrido. Si no, se queda acá: el visitante escaneó otra cosa y puede
/// seguir intentando.
///
/// Quién decide si el código sirve es el servidor (SIS01). Esta pantalla no
/// sabe cuál era el correcto, sólo manda lo que leyó.
class PantallaEscaneo extends StatefulWidget {
  final DesafioJugable desafio;

  const PantallaEscaneo({super.key, required this.desafio});

  @override
  State<PantallaEscaneo> createState() => _PantallaEscaneoState();
}

class _PantallaEscaneoState extends State<PantallaEscaneo> {
  // Sólo códigos QR: limitar los formatos le ahorra trabajo al lector y evita
  // que un código de barras cualquiera dispare una consulta.
  final _controlador = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// Mientras se consulta al servidor no se lee nada más. Sin esto, la cámara
  /// dispararía un pedido por cada cuadro que ve el código.
  bool _consultando = false;

  /// Los códigos que el servidor ya rechazó. Se recuerdan para poder dejar la
  /// cámara encendida: apuntar de nuevo al mismo cartel equivocado no vuelve a
  /// preguntar, pero apuntar a otro responde al instante.
  final _rechazados = <String>{};

  String _error = '';

  /// Cuando falla la consulta (y no el código), la cámara queda apagada y hay
  /// que reintentar a mano: reintentar solo sería insistirle a una red que
  /// recién falló.
  bool _apagadaPorError = false;

  /// La cámara no arrancó: falta el permiso, o el aparato no puede. Sirve para
  /// esconder las indicaciones de escaneo, que sin cámara no significan nada.
  /// Nunca vuelve a false porque de esa pantalla sólo se sale saliendo del
  /// escaneo.
  bool _camaraFallo = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _alLeer(BarcodeCapture captura) async {
    if (_consultando) return;

    String? codigo;
    for (final leido in captura.barcodes) {
      final valor = leido.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        codigo = valor;
        break;
      }
    }
    // Un QR vacío o ilegible: no hay nada que mandar.
    if (codigo == null) return;
    if (_rechazados.contains(codigo)) return;

    setState(() {
      _consultando = true;
      _error = '';
    });

    try {
      final resultado = await escanearCodigo(widget.desafio.id, codigo);
      if (!mounted) return;

      if (resultado.correcto) {
        Navigator.of(context).pop(resultado);
        return;
      }
      setState(() {
        _rechazados.add(codigo!);
        _error = 'Ese no es el código de la pieza que buscás. '
            'Fijate que sea el cartel que está junto a la pieza correcta.';
      });
    } on ErrorApi catch (error) {
      if (!mounted) return;
      await _controlador.stop();
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _apagadaPorError = true;
      });
    } catch (error, pila) {
      debugPrint('Fallo al comprobar el código escaneado: $error\n$pila');
      if (!mounted) return;
      await _controlador.stop();
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo comprobar el código. Probá de nuevo.';
        _apagadaPorError = true;
      });
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _reintentar() async {
    setState(() {
      _error = '';
      _apagadaPorError = false;
    });
    try {
      await _controlador.start();
    } on MobileScannerException catch (error) {
      debugPrint('No se pudo reanudar la cámara: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, restricciones) {
              // El recuadro ocupa el 70% del lado más corto: lo bastante
              // grande para apuntar sin pulso de cirujano.
              final lado = restricciones.biggest.shortestSide * 0.7;
              final ventana = Rect.fromCenter(
                center: restricciones.biggest.center(Offset.zero),
                width: lado,
                height: lado,
              );
              return MobileScanner(
                controller: _controlador,
                // Sólo cuenta lo que entra en el recuadro. Si no, el marco
                // sería un dibujo que miente: leería códigos de afuera.
                scanWindow: ventana,
                onDetect: _alLeer,
                errorBuilder: _camaraConProblema,
                // El size es obligatorio: un CustomPaint sin hijo mide cero y
                // el velo, que se calcula sobre ese tamaño, no se vería.
                overlayBuilder: (context, restriccionesDelMarco) => CustomPaint(
                  size: restriccionesDelMarco.biggest,
                  painter: _MarcoPainter(ventana: ventana),
                ),
              );
            },
          ),
          // La pantalla de cámara rota se basta sola: trae su propio botón
          // para volver, así que encima no va nada.
          if (!_camaraFallo)
            SafeArea(
              child: Column(
                children: [
                  _Encabezado(desafio: widget.desafio, controlador: _controlador),
                  const Spacer(),
                  _Pie(
                    consultando: _consultando,
                    error: _error,
                    alReintentar: _apagadaPorError ? _reintentar : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Qué mostrar cuando la cámara no arranca. El caso que importa es el
  /// permiso denegado: una pantalla negra sin explicación parecería la app
  /// rota, cuando en realidad falta una autorización de Android.
  Widget _camaraConProblema(BuildContext context, MobileScannerException error) {
    // errorBuilder corre en pleno build, así que el cambio de estado se agenda
    // para cuando ese build termine: cambiarlo ahora sería construir dos veces
    // el mismo cuadro y Flutter lo rechaza.
    if (!_camaraFallo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _camaraFallo = true);
      });
    }

    final sinPermiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final noSePuede = error.errorCode == MobileScannerErrorCode.unsupported;

    return ColoredBox(
      color: AppColors.fondo,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                sinPermiso ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                color: AppColors.textoInactivo,
                size: 42,
              ),
              const SizedBox(height: 18),
              Text(
                sinPermiso
                    ? 'La app no puede usar la cámara'
                    : noSePuede
                        ? 'Este dispositivo no puede escanear'
                        : 'No se pudo abrir la cámara',
                textAlign: TextAlign.center,
                style: AppText.serif(size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                sinPermiso
                    ? 'Para escanear los códigos de las piezas hace falta permiso '
                        'para usar la cámara. Si no te lo volvió a preguntar, '
                        'habilitalo desde los ajustes de Android, en los permisos '
                        'de esta app.'
                    : 'Volvé a la misión y probá de nuevo en un momento.',
                textAlign: TextAlign.center,
                style: AppText.sans(size: 14),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.acento),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                child: Text(
                  'Volver al desafío',
                  style: AppText.sans(size: 14, color: AppColors.acento, peso: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La barra de arriba: salir, qué se está buscando y la linterna.
class _Encabezado extends StatelessWidget {
  final DesafioJugable desafio;
  final MobileScannerController controlador;

  const _Encabezado({required this.desafio, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            tooltip: 'Volver al desafío',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escaneá el código',
                  style: AppText.sans(size: 15, color: Colors.white, peso: FontWeight.w700),
                ),
                Text(
                  // En la búsqueda guiada no se sabe el nombre de la pieza:
                  // el servidor no lo manda hasta que se la encuentra.
                  desafio.pieza ?? 'El cartel está junto a la pieza',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          // La linterna no estaba en la historia, pero las salas de museo son
          // oscuras y sin ella el lector no engancha el código.
          IconButton(
            onPressed: () => controlador.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
            color: Colors.white,
            tooltip: 'Encender o apagar la linterna',
          ),
        ],
      ),
    );
  }
}

/// La franja de abajo: qué está pasando, o qué salió mal.
class _Pie extends StatelessWidget {
  final bool consultando;
  final String error;
  final Future<void> Function()? alReintentar;

  const _Pie({required this.consultando, required this.error, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      color: Colors.black54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error.isNotEmpty) ...[
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 14, color: Colors.white),
            ),
            if (alReintentar != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: alReintentar,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.acento),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                ),
                child: Text(
                  'Reintentar',
                  style: AppText.sans(size: 14, color: AppColors.acento, peso: FontWeight.w700),
                ),
              ),
            ],
          ] else
            Text(
              consultando ? 'Comprobando el código…' : 'Apuntá al código QR del cartel',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 14, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

/// Oscurece todo menos el recuadro de lectura y le marca las esquinas.
///
/// Las esquinas en vez del rectángulo entero son a propósito: dejan ver el
/// código sin una línea encima justo donde el lector tiene que mirar.
class _MarcoPainter extends CustomPainter {
  final Rect ventana;

  const _MarcoPainter({required this.ventana});

  @override
  void paint(Canvas lienzo, Size tamano) {
    final recuadro = RRect.fromRectAndRadius(ventana, const Radius.circular(16));

    // El velo se dibuja como "toda la pantalla menos el recuadro": con dos
    // rectángulos quedaría una franja sin cubrir.
    final velo = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & tamano),
      Path()..addRRect(recuadro),
    );
    lienzo.drawPath(velo, Paint()..color = Colors.black54);

    final trazo = Paint()
      ..color = AppColors.acento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const largo = 28.0;
    final esquinas = [
      // Cada esquina son dos segmentos que salen del vértice.
      [ventana.topLeft, const Offset(largo, 0), const Offset(0, largo)],
      [ventana.topRight, const Offset(-largo, 0), const Offset(0, largo)],
      [ventana.bottomLeft, const Offset(largo, 0), const Offset(0, -largo)],
      [ventana.bottomRight, const Offset(-largo, 0), const Offset(0, -largo)],
    ];
    for (final esquina in esquinas) {
      final vertice = esquina[0];
      lienzo.drawLine(vertice, vertice + esquina[1], trazo);
      lienzo.drawLine(vertice, vertice + esquina[2], trazo);
    }
  }

  @override
  bool shouldRepaint(_MarcoPainter anterior) => anterior.ventana != ventana;
}
