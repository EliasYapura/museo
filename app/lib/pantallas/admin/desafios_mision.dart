import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/desafio.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';
import 'desafio_admin.dart';

/// Los desafíos de una misión, en el orden en que los resuelve el visitante.
///
/// Por ahora solo se ven: crear, editar, reordenar y borrar llegan después.
class PantallaDesafiosMision extends StatefulWidget {
  final int misionId;

  /// El nombre que ya conoce la pantalla anterior, para titular mientras carga
  /// en vez de dejar el encabezado vacío.
  final String? nombreConocido;

  const PantallaDesafiosMision({
    super.key,
    required this.misionId,
    this.nombreConocido,
  });

  @override
  State<PantallaDesafiosMision> createState() => _PantallaDesafiosMisionState();
}

class _PantallaDesafiosMisionState extends State<PantallaDesafiosMision> {
  Future<({String mision, List<Desafio> desafios})>? _datos;

  /// El orden de los desafíos después de arrastrar uno.
  ///
  /// Mientras sea null vale el que trajo la carga. Se guarda acá en vez de
  /// reemplazar el future porque eso mandaría la pantalla a "cargando" y la
  /// lista desaparecería en medio del arrastre.
  List<Desafio>? _reordenados;

  /// Mientras se guarda el orden nuevo no se puede arrastrar de nuevo: dos
  /// cambios a la vez dejarían al servidor y a la pantalla contando distinto.
  bool _moviendo = false;
  String _error = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datos ??= _pedir();
  }

  Future<({String mision, List<Desafio> desafios})> _pedir() {
    final pedido = listarDesafios(ProveedorSesion.de(context).token!, widget.misionId);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  /// Abre el alta o la edición. Si hubo cambios, el listado se vuelve a pedir.
  Future<void> _abrir({Desafio? desafio, int? posicion}) async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaDesafioAdmin(
          misionId: widget.misionId,
          desafio: desafio,
          posicion: posicion,
        ),
      ),
    );
    if (huboCambios == true) await _recargar();
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _datos = pedido;
      // Recargar es pedir el estado de verdad: el orden que quedó de un
      // arrastre anterior ya no manda.
      _reordenados = null;
      _error = '';
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  /// Mueve un desafío de lugar y manda la lista completa en el orden nuevo.
  ///
  /// La pantalla muestra el cambio antes de que conteste el servidor, para que
  /// el arrastre no se sienta trabado. Si la API lo rechaza, vuelve al orden
  /// anterior y lo avisa.
  Future<void> _mover(List<Desafio> actuales, int desde, int hasta) async {
    if (desde == hasta) return;

    final sesion = ProveedorSesion.de(context);
    final anteriores = List<Desafio>.from(actuales);
    final nuevos = List<Desafio>.from(actuales);
    nuevos.insert(hasta, nuevos.removeAt(desde));

    setState(() {
      _reordenados = nuevos;
      _moviendo = true;
      _error = '';
    });

    try {
      final guardados = await reordenarDesafios(
        sesion.token!,
        widget.misionId,
        nuevos.map((d) => d.id).toList(),
      );
      if (!mounted) return;
      // Se queda con lo que devolvió la API, que trae los números de orden ya
      // renumerados de 1 en adelante.
      setState(() => _reordenados = guardados);
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _reordenados = anteriores;
        _error = error.mensaje;
      });
    } catch (error, pila) {
      debugPrint('Fallo al reordenar: $error\n$pila');
      if (!mounted) return;
      setState(() {
        _reordenados = anteriores;
        _error = 'No se pudo cambiar el orden.';
      });
    } finally {
      if (mounted) setState(() => _moviendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<({String mision, List<Desafio> desafios})>(
          future: _datos,
          builder: (context, snapshot) {
            final cargado = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.textoPrimario,
                        tooltip: 'Volver',
                      ),
                      Expanded(
                        child: Text(
                          'Desafíos',
                          style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
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
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cargado?.mision ?? widget.nombreConocido ?? 'Misión',
                        style: AppText.serif(size: 24),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 18,
                        width: double.infinity,
                        child: CustomPaint(painter: GrecaPainter()),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Expanded(child: _contenido(context, snapshot, sesion)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        backgroundColor: AppColors.acento,
        foregroundColor: AppColors.fondo,
        icon: const Icon(Icons.add),
        label: Text(
          'Nuevo desafío',
          style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<({String mision, List<Desafio> desafios})> snapshot,
    ControlSesion sesion,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: AppColors.acento));
    }

    if (snapshot.hasError) {
      final error = snapshot.error;
      // Un token vencido no se arregla reintentando: hay que volver a entrar.
      if (error is ErrorApi && error.sesionVencida) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          sesion.cerrarSesion();
          Navigator.of(context).pop();
        });
      }
      return _Centrado(
        texto: error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
        alReintentar: _recargar,
      );
    }

    final desafios = _reordenados ?? snapshot.data?.desafios ?? const <Desafio>[];
    if (desafios.isEmpty) {
      return _Centrado(
        texto: 'Esta misión todavía no tiene desafíos.\n'
            'Sin al menos uno no se puede publicar.',
        alReintentar: _recargar,
        // Acá no falló nada: no hay nada que reintentar, solo volver a mirar.
        textoBoton: 'Actualizar',
      );
    }

    return Column(
      children: [
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Aviso(_error),
          ),
        if (desafios.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, size: 16, color: AppColors.textoInactivo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Arrastrá de acá para cambiar el orden del recorrido.',
                    style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recargar,
            color: AppColors.acento,
            backgroundColor: AppColors.superficie,
            child: ReorderableListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: desafios.length,
              // El arrastre arranca sólo desde el asa, no desde la tarjeta:
              // si no, mover y abrir para editar se pelearían por el mismo
              // gesto.
              buildDefaultDragHandles: false,
              // onReorderItem y no onReorder: ya entrega el destino contando
              // la lista sin el elemento que se movió, que es lo que hace
              // falta para insertarlo.
              onReorderItem: (desde, hasta) => _mover(desafios, desde, hasta),
              proxyDecorator: (hijo, _, __) => Material(
                color: Colors.transparent,
                child: hijo,
              ),
              itemBuilder: (_, i) => Padding(
                // La key tiene que ser estable y propia de cada desafío: es
                // con lo que la lista sabe cuál se movió.
                key: ValueKey(desafios[i].id),
                padding: const EdgeInsets.only(bottom: 12),
                child: _Tarjeta(
                  desafio: desafios[i],
                  indice: i,
                  sePuedeMover: desafios.length > 1 && !_moviendo,
                  alTocar: () => _abrir(desafio: desafios[i], posicion: i + 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Desafio desafio;

  /// Posición en la lista, que es lo que necesita el asa para saber qué mover.
  final int indice;

  /// Con un solo desafío no hay nada que ordenar, y mientras se guarda un
  /// cambio de orden no se deja arrastrar otro.
  final bool sePuedeMover;

  final VoidCallback alTocar;

  const _Tarjeta({
    required this.desafio,
    required this.indice,
    required this.sePuedeMover,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El número es la posición en la lista y no la columna orden de
              // la base: al borrar uno, la base deja el hueco (el 1, 2, 3 pasa
              // a ser 2, 3) hasta que se reordene. El visitante los resuelve
              // en fila, así que lo que ve es la posición.
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  '${indice + 1}',
                  style: AppText.sans(
                    size: 13,
                    color: AppColors.acento,
                    peso: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  desafio.enunciado,
                  style: AppText.serif(size: 16),
                ),
              ),
              if (sePuedeMover) ...[
                const SizedBox(width: 8),
                // El asa es lo único que inicia el arrastre; el resto de la
                // tarjeta sigue abriendo el desafío para editarlo.
                ReorderableDragStartListener(
                  index: indice,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 22,
                      color: AppColors.textoInactivo,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  desafio.nombreDelTipo,
                  style: AppText.sans(size: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${desafio.puntos} ${desafio.puntos == 1 ? 'punto' : 'puntos'}',
                style: AppText.sans(size: 12.5, color: AppColors.acento, peso: FontWeight.w700),
              ),
            ],
          ),
          // Lo propio del tipo y la pieza asociada: sirven para revisar la
          // misión sin abrir cada desafío.
          if (desafio.resumen != null || desafio.objeto != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desafio.resumen != null)
                  Text(
                    desafio.resumen!,
                    style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
                  ),
                if (desafio.resumen != null && desafio.objeto != null)
                  Text('  ·  ', style: AppText.sans(size: 12.5, color: AppColors.textoInactivo)),
                if (desafio.objeto != null)
                  Expanded(
                    child: Text(
                      desafio.objeto!,
                      style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    // La tarjeta entera abre la edición, igual que en el listado de misiones:
    // en un teléfono un botón al costado de cada fila no entra y se toca el
    // equivocado.
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: contenido,
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
