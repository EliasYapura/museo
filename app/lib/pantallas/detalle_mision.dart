import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/mision.dart';

/// Cómo se juega una misión. Está escrito acá y no en la base porque es igual
/// para todas: la descripción que carga el administrador cuenta de qué se
/// trata esta misión; esto cuenta cómo funciona el juego (VIS03).
const _instrucciones = [
  'Recorré las salas buscando la pieza que te indica cada desafío.',
  'Escaneá el código QR que está junto a la pieza para confirmar que la encontraste.',
  'Respondé lo que te pregunten sobre ella y sumá puntos.',
];

/// Detalle de una misión, antes de empezarla (VIS03).
class PantallaDetalleMision extends StatefulWidget {
  final Mision mision;

  /// Recibe la misión del listado para poder mostrar el nombre enseguida,
  /// mientras llega el detalle completo con las salas del recorrido.
  const PantallaDetalleMision({super.key, required this.mision});

  @override
  State<PantallaDetalleMision> createState() => _PantallaDetalleMisionState();
}

class _PantallaDetalleMisionState extends State<PantallaDetalleMision> {
  late Future<Mision> _detalle;

  @override
  void initState() {
    super.initState();
    _detalle = _pedir();
  }

  // Igual que en el listado: ignore() evita que un fallo inmediato se reporte
  // como excepción sin atender antes de que FutureBuilder escuche.
  Future<Mision> _pedir() {
    final pedido = obtenerMision(widget.mision.id);
    pedido.ignore();
    return pedido;
  }

  Future<void> _reintentar() async {
    final pedido = _pedir();
    setState(() {
      _detalle = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textoPrimario,
                    tooltip: 'Volver a las misiones',
                  ),
                  Expanded(
                    child: Text(
                      'Misión',
                      style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Mision>(
                future: _detalle,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }
                  if (snapshot.hasError) {
                    return _Error(
                      mensaje: snapshot.error is ErrorApi
                          ? (snapshot.error as ErrorApi).mensaje
                          : 'Ocurrió un problema inesperado.',
                      alReintentar: _reintentar,
                    );
                  }
                  return _Detalle(mision: snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() alReintentar;

  const _Error({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No se pudo abrir la misión',
              textAlign: TextAlign.center,
              style: AppText.serif(size: 18),
            ),
            const SizedBox(height: 10),
            Text(mensaje, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: alReintentar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(
                'Reintentar',
                style: AppText.sans(size: 14, color: AppColors.acento, peso: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  final Mision mision;
  const _Detalle({required this.mision});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(mision.nombre, style: AppText.serif(size: 26)),
        const SizedBox(height: 14),
        SizedBox(
          height: 18,
          width: double.infinity,
          child: CustomPaint(painter: GrecaPainter()),
        ),
        const SizedBox(height: 18),

        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borde),
            ),
            child: CustomPaint(painter: IconoPainter(mision.icono)),
          ),
        ),
        const SizedBox(height: 20),

        // Los datos sueltos, en etiquetas que se acomodan solas al ancho.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Dato(texto: '${mision.duracionMin} min aprox.'),
            _Dato(texto: mision.dificultad.etiqueta, color: mision.dificultad.color),
            _Dato(texto: '${mision.desafios} ${mision.desafios == 1 ? 'desafío' : 'desafíos'}'),
            _Dato(texto: '${mision.puntos} pts', color: AppColors.acento),
          ],
        ),
        const SizedBox(height: 22),

        Text(mision.descripcion, style: AppText.sans(size: 15)),

        if (mision.salas.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Dónde se juega', style: AppText.serif(size: 17)),
          const SizedBox(height: 8),
          for (final sala in mision.salas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $sala', style: AppText.sans(size: 14)),
            ),
        ],

        const SizedBox(height: 24),
        Text('Cómo funciona', style: AppText.serif(size: 17)),
        const SizedBox(height: 10),
        for (var i = 0; i < _instrucciones.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El número va en un círculo para que se lea como paso y no
                // como viñeta suelta.
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.superficie,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.sans(size: 12, color: AppColors.acento, peso: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_instrucciones[i], style: AppText.sans(size: 14))),
              ],
            ),
          ),

        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // El recorrido en sí es VIS04.
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acento,
              disabledBackgroundColor: AppColors.superficie,
              disabledForegroundColor: AppColors.textoInactivo,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Comenzar recorrido',
              style: AppText.sans(size: 15, color: AppColors.textoInactivo, peso: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// Etiqueta con un dato suelto de la misión.
class _Dato extends StatelessWidget {
  final String texto;
  final Color? color;
  const _Dato({required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(texto, style: AppText.sans(size: 13)),
        ],
      ),
    );
  }
}
