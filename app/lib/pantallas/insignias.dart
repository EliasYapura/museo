import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/insignia_visitante.dart';
import '../sesion/sesion.dart';
import 'registro.dart';

/// Pestaña Insignias: los logros del museo y cuáles ya ganó el visitante
/// (VIS10).
///
/// Sin cuenta se ve el catálogo completo, todas sin ganar, y se explica por
/// qué: no hay dónde guardarlas. Esconderlas sería peor — saber qué hay para
/// conseguir es parte de querer conseguirlo.
class PantallaInsignias extends StatefulWidget {
  const PantallaInsignias({super.key});

  @override
  State<PantallaInsignias> createState() => _PantallaInsigniasState();
}

class _PantallaInsigniasState extends State<PantallaInsignias> {
  Future<List<InsigniaVisitante>>? _insignias;

  /// Con qué sesión se pidió la lista. Si cambia —entró, salió o se registró—
  /// hay que volver a pedirla, porque lo que cambia es justamente cuáles tiene.
  String? _tokenDelPedido;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = ProveedorSesion.de(context).token;
    if (_insignias != null && token == _tokenDelPedido) return;
    _tokenDelPedido = token;
    _insignias = _pedir(token);
  }

  Future<List<InsigniaVisitante>> _pedir(String? token) {
    final pedido = obtenerInsignias(token: token);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final token = ProveedorSesion.de(context).token;
    final pedido = _pedir(token);
    setState(() {
      _tokenDelPedido = token;
      _insignias = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Museo de La Plata',
                        style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 6),
                      Text('Insignias', style: AppText.serif(size: 26)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh),
                  color: AppColors.acento,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(painter: GrecaPainter()),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _contenido(sesion)),
        ],
      ),
    );
  }

  Widget _contenido(ControlSesion sesion) {
    return FutureBuilder<List<InsigniaVisitante>>(
      future: _insignias,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.acento));
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          return _Centrado(
            texto: error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
            alReintentar: _recargar,
          );
        }

        final insignias = snapshot.data ?? const <InsigniaVisitante>[];
        if (insignias.isEmpty) {
          return _Centrado(
            texto: 'El museo todavía no tiene insignias para ganar.',
            alReintentar: _recargar,
            textoBoton: 'Actualizar',
          );
        }

        final ganadas = insignias.where((i) => i.obtenida).length;

        return RefreshIndicator(
          onRefresh: _recargar,
          color: AppColors.acento,
          backgroundColor: AppColors.superficie,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              if (!sesion.haySesion)
                _SinCuenta()
              else
                Text(
                  ganadas == 0
                      ? 'Todavía no ganaste ninguna. Terminá una misión para empezar.'
                      : 'Ganaste $ganadas de ${insignias.length}.',
                  style: AppText.sans(size: 14),
                ),
              const SizedBox(height: 18),
              for (final insignia in insignias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Tarjeta(insignia: insignia),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// El aviso para quien recorre sin cuenta.
///
/// Las insignias se guardan contra el visitante, así que sin cuenta no hay
/// dónde ponerlas. Vale decirlo acá y no esconder la pestaña: es el momento en
/// que se entiende para qué sirve registrarse.
class _SinCuenta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estas son las insignias del museo.', style: AppText.sans(size: 14.5)),
          const SizedBox(height: 6),
          Text(
            'Para que las que ganes te queden guardadas necesitás una cuenta. '
            'Sin cuenta podés recorrer todas las misiones igual, pero al salir '
            'no queda registro de lo que lograste.',
            style: AppText.sans(size: 13.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaRegistro()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Crear una cuenta',
                style: AppText.sans(size: 15, color: AppColors.acento, peso: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final InsigniaVisitante insignia;

  const _Tarjeta({required this.insignia});

  @override
  Widget build(BuildContext context) {
    final ganada = insignia.obtenida;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ganada ? AppColors.acento : AppColors.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Las que faltan se ven apagadas, no escondidas: el visitante tiene
          // que poder saber qué le falta para ganarlas.
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fondo,
              shape: BoxShape.circle,
              border: Border.all(color: ganada ? AppColors.acento : AppColors.borde),
            ),
            child: Icon(
              ganada ? Icons.hexagon : Icons.hexagon_outlined,
              size: 22,
              color: ganada ? AppColors.acento : AppColors.textoInactivo,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insignia.nombre,
                  style: AppText.serif(
                    size: 17,
                    color: ganada ? AppColors.textoPrimario : AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Text(insignia.descripcion, style: AppText.sans(size: 13.5)),
                const SizedBox(height: 8),
                Text(
                  ganada ? 'Ganada' : 'Todavía no la tenés',
                  style: AppText.sans(
                    size: 12.5,
                    color: ganada ? AppColors.facil : AppColors.textoInactivo,
                    peso: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Centrado extends StatelessWidget {
  final String texto;
  final Future<void> Function() alReintentar;
  final String textoBoton;

  const _Centrado({
    required this.texto,
    required this.alReintentar,
    this.textoBoton = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(texto, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: alReintentar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento),
              ),
              child: Text(
                textoBoton,
                style: AppText.sans(size: 14, color: AppColors.acento, peso: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
