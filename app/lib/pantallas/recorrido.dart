import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/desafio_jugable.dart';
import '../modelos/mision.dart';

/// El recorrido de una misión: muestra el desafío que toca resolver (VIS04).
///
/// Los desafíos se piden una sola vez al entrar y quedan en memoria mientras
/// dura el recorrido. Guardar el avance para poder retomarlo es SIS02 y SIS03,
/// del Sprint 4: por ahora, salir del recorrido lo descarta.
class PantallaRecorrido extends StatefulWidget {
  final Mision mision;

  const PantallaRecorrido({super.key, required this.mision});

  @override
  State<PantallaRecorrido> createState() => _PantallaRecorridoState();
}

class _PantallaRecorridoState extends State<PantallaRecorrido> {
  late Future<List<DesafioJugable>> _desafios;

  /// Qué desafío de la lista se está jugando. Por ahora es final porque
  /// avanzar es parte de resolverlos, y resolverlos es VIS05 y VIS06.
  final int _indice = 0;

  @override
  void initState() {
    super.initState();
    _desafios = _pedir();
  }

  // Igual que en el listado y el detalle: ignore() evita que un fallo
  // inmediato se reporte como excepción sin atender antes de que
  // FutureBuilder alcance a escuchar.
  Future<List<DesafioJugable>> _pedir() {
    final pedido = obtenerDesafiosJugables(widget.mision.id);
    pedido.ignore();
    return pedido;
  }

  Future<void> _reintentar() async {
    final pedido = _pedir();
    setState(() {
      _desafios = pedido;
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
                    tooltip: 'Salir del recorrido',
                  ),
                  Expanded(
                    child: Text(
                      widget.mision.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DesafioJugable>>(
                future: _desafios,
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

                  final desafios = snapshot.data!;
                  return _Desafio(
                    desafio: desafios[_indice],
                    posicion: _indice + 1,
                    total: desafios.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El desafío que toca, con todo lo que el visitante necesita para resolverlo.
class _Desafio extends StatelessWidget {
  final DesafioJugable desafio;

  /// Qué número de desafío es, contando desde 1. Es la posición en el
  /// recorrido y no el `orden` que guarda la base: así, si el administrador
  /// borró uno y quedó un hueco en la numeración, el visitante no lo ve.
  final int posicion;
  final int total;

  const _Desafio({required this.desafio, required this.posicion, required this.total});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        _Avance(posicion: posicion, total: total),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Text(
                'Desafío $posicion de $total',
                style: AppText.sans(size: 13, color: AppColors.textoSecundario),
              ),
            ),
            Text(
              '${desafio.puntos} pts',
              style: AppText.sans(size: 13, color: AppColors.acento, peso: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 18,
          width: double.infinity,
          child: CustomPaint(painter: GrecaPainter()),
        ),
        const SizedBox(height: 20),

        Text(desafio.enunciado, style: AppText.serif(size: 21)),
        const SizedBox(height: 24),

        if (desafio.requiereEscaneo) _Pieza(desafio: desafio),

        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Escanear es VIS05 y responder es VIS06.
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acento,
              disabledBackgroundColor: AppColors.superficie,
              disabledForegroundColor: AppColors.textoInactivo,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              // El escaneo va primero: hay que llegar a la pieza antes de que
              // tenga sentido preguntar algo sobre ella.
              desafio.requiereEscaneo ? 'Escanear el código' : 'Responder',
              style: AppText.sans(size: 15, color: AppColors.textoInactivo, peso: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de a cuántos desafíos se llegó, un segmento por desafío.
///
/// Son segmentos y no una barra continua porque la cuenta es de desafíos
/// enteros: se ve de un vistazo cuántos faltan.
class _Avance extends StatelessWidget {
  final int posicion;
  final int total;

  const _Avance({required this.posicion, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= posicion ? AppColors.acento : AppColors.borde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Qué pieza hay que buscar y en qué sala.
///
/// El nombre puede no venir: en la búsqueda guiada el servidor no lo manda,
/// porque deducir cuál es la pieza es justamente el desafío. Ahí queda la sala
/// sola, que es lo único que se puede decir sin resolverlo.
class _Pieza extends StatelessWidget {
  final DesafioJugable desafio;

  const _Pieza({required this.desafio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.place_outlined, size: 20, color: AppColors.acento),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desafio.pieza == null ? 'Dónde buscar' : 'Buscá esta pieza',
                  style: AppText.sans(size: 12.5, color: AppColors.textoSecundario)
                      .copyWith(letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                if (desafio.pieza != null) ...[
                  Text(desafio.pieza!, style: AppText.serif(size: 17)),
                  const SizedBox(height: 4),
                ],
                Text(
                  desafio.sala ?? 'El museo no registró la sala de esta pieza.',
                  style: AppText.sans(
                    size: desafio.pieza == null ? 16 : 13.5,
                    color: desafio.pieza == null ? AppColors.textoPrimario : AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cuando la encuentres, escaneá el código que está junto a ella.',
                  style: AppText.sans(size: 13),
                ),
              ],
            ),
          ),
        ],
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
              'No se pudo empezar el recorrido',
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
