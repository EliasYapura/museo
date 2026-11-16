import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/estadisticas.dart';
import '../../sesion/sesion.dart';

/// Estadísticas de uso de las misiones (ADM22).
///
/// Arriba el resumen del museo y abajo una fila por misión, ordenadas por
/// participaciones: lo primero que se quiere saber es qué se juega y qué no.
///
/// Cada número dice de dónde sale. Las participaciones salen de la bitácora,
/// que registra también a los visitantes sin cuenta; los tiempos salen del
/// progreso guardado, que existe sólo con cuenta. Sin aclararlo, los dos
/// números parecen contradecirse.
class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  Future<({ResumenDeUso resumen, List<UsoDeMision> misiones})>? _datos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datos ??= _pedir();
  }

  Future<({ResumenDeUso resumen, List<UsoDeMision> misiones})> _pedir() {
    final pedido = obtenerEstadisticas(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    setState(() {
      _datos = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  Future<void> _abrir(UsoDeMision mision) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaEstadisticasMision(mision: mision)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecera(titulo: 'Estadísticas', alActualizar: _recargar),
            Expanded(
              child: FutureBuilder<({ResumenDeUso resumen, List<UsoDeMision> misiones})>(
                future: _datos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
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

                  final datos = snapshot.data!;
                  if (datos.resumen.participaciones == 0) {
                    return _Centrado(
                      texto: 'Todavía nadie jugó ninguna misión. Cuando los visitantes empiecen '
                          'a recorrer, acá aparece cómo les va.',
                      alReintentar: _recargar,
                    );
                  }

                  // Las misiones que nadie jugó van al final y no se esconden:
                  // que una misión publicada tenga cero participaciones es
                  // justamente algo que el museo tiene que ver.
                  final misiones = datos.misiones;

                  return RefreshIndicator(
                    onRefresh: _recargar,
                    color: AppColors.acento,
                    backgroundColor: AppColors.superficie,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _Resumen(resumen: datos.resumen),
                        const SizedBox(height: 22),
                        Text('Por misión', style: AppText.serif(size: 17)),
                        const SizedBox(height: 4),
                        Text(
                          'Ordenadas por cuántas veces se empezaron.',
                          style: AppText.sans(size: 12.5),
                        ),
                        const SizedBox(height: 12),
                        for (final mision in misiones) ...[
                          _FilaMision(mision: mision, alTocar: () => _abrir(mision)),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
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

/// El resumen de todo el museo.
class _Resumen extends StatelessWidget {
  final ResumenDeUso resumen;

  const _Resumen({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final desde = resumen.desde;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Dato(
                numero: '${resumen.participaciones}',
                etiqueta: resumen.participaciones == 1 ? 'participación' : 'participaciones',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Dato(
                numero: resumen.porcentajeCompletado == null
                    ? '—'
                    : '${resumen.porcentajeCompletado}%',
                etiqueta: 'se terminaron',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Dato(numero: '${resumen.pistas}', etiqueta: 'pistas pedidas')),
            const SizedBox(width: 10),
            Expanded(child: _Dato(numero: '${resumen.fallos}', etiqueta: 'intentos fallidos')),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde),
          ),
          child: Text(
            'De las ${resumen.participaciones} participaciones, '
            '${resumen.participacionesSinCuenta} fueron de visitantes sin cuenta. '
            'Esos recorridos se cuentan acá, pero no dejan progreso guardado, '
            'así que no entran en los tiempos.'
            '${desde == null ? '' : ' Se mide desde el ${_fecha(desde)}.'}',
            style: AppText.sans(size: 12.5),
          ),
        ),
      ],
    );
  }
}

/// Un número grande con su etiqueta.
class _Dato extends StatelessWidget {
  final String numero;
  final String etiqueta;

  const _Dato({required this.numero, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Junto, si no el lector de pantalla lee el número y la etiqueta como
      // dos cosas sueltas.
      label: '$numero $etiqueta',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(numero, style: AppText.serif(size: 26)),
            const SizedBox(height: 2),
            Text(etiqueta, style: AppText.sans(size: 12.5)),
          ],
        ),
      ),
    );
  }
}

/// Una misión en el listado del tablero.
class _FilaMision extends StatelessWidget {
  final UsoDeMision mision;
  final VoidCallback alTocar;

  const _FilaMision({required this.mision, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final sinJugar = mision.participaciones == 0;

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mision.nombre,
                    style: AppText.sans(size: 14.5, peso: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!mision.activa) ...[
                  const SizedBox(width: 8),
                  Text(
                    'sin publicar',
                    style: AppText.sans(size: 11.5, color: AppColors.textoInactivo),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (sinJugar)
              Text(
                'Todavía nadie la jugó.',
                style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _Pizca(
                    icono: Icons.play_arrow_outlined,
                    texto: '${mision.participaciones}',
                    etiqueta: '${mision.participaciones} participaciones',
                  ),
                  _Pizca(
                    icono: Icons.flag_outlined,
                    texto: mision.porcentajeCompletado == null
                        ? '—'
                        : '${mision.porcentajeCompletado}%',
                    etiqueta: '${mision.porcentajeCompletado ?? 0} por ciento terminadas',
                  ),
                  if (mision.minutosMediana != null)
                    _Pizca(
                      icono: Icons.schedule,
                      texto: mision.tiempoEnTexto,
                      etiqueta: 'tiempo mediano ${mision.tiempoEnTexto}',
                    ),
                  if (mision.pistas > 0)
                    _Pizca(
                      icono: Icons.lightbulb_outline,
                      texto: '${mision.pistas}',
                      etiqueta: '${mision.pistas} pistas pedidas',
                    ),
                  if (mision.fallos > 0)
                    _Pizca(
                      icono: Icons.close,
                      texto: '${mision.fallos}',
                      etiqueta: '${mision.fallos} intentos fallidos',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Un dato chico con su ícono, de los que van en fila.
class _Pizca extends StatelessWidget {
  final IconData icono;
  final String texto;

  /// Lo que lee el lector de pantalla: el ícono no dice nada por su cuenta.
  final String etiqueta;

  const _Pizca({required this.icono, required this.texto, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: AppColors.textoSecundario),
          const SizedBox(width: 4),
          Text(texto, style: AppText.sans(size: 12.5)),
        ],
      ),
    );
  }
}

/// El detalle de una misión: cómo le fue a cada uno de sus desafíos.
class PantallaEstadisticasMision extends StatefulWidget {
  /// Lo que ya sabe el listado, para mostrar algo mientras llega el detalle.
  final UsoDeMision mision;

  const PantallaEstadisticasMision({super.key, required this.mision});

  @override
  State<PantallaEstadisticasMision> createState() => _PantallaEstadisticasMisionState();
}

class _PantallaEstadisticasMisionState extends State<PantallaEstadisticasMision> {
  Future<({UsoDeMision mision, List<UsoDeDesafio> desafios})>? _datos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datos ??= _pedir();
  }

  Future<({UsoDeMision mision, List<UsoDeDesafio> desafios})> _pedir() {
    final pedido = obtenerEstadisticasDeMision(
      ProveedorSesion.de(context).token!,
      widget.mision.id,
    );
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    setState(() {
      _datos = pedido;
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
            _Cabecera(titulo: widget.mision.nombre, alActualizar: _recargar),
            Expanded(
              child: FutureBuilder<({UsoDeMision mision, List<UsoDeDesafio> desafios})>(
                future: _datos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return _Centrado(
                      texto: error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
                      alReintentar: _recargar,
                    );
                  }

                  final datos = snapshot.data!;
                  final mision = datos.mision;

                  return RefreshIndicator(
                    onRefresh: _recargar,
                    color: AppColors.acento,
                    backgroundColor: AppColors.superficie,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Dato(
                                numero: '${mision.participaciones}',
                                etiqueta: mision.participaciones == 1
                                    ? 'participación'
                                    : 'participaciones',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Dato(
                                numero: mision.porcentajeCompletado == null
                                    ? '—'
                                    : '${mision.porcentajeCompletado}%',
                                etiqueta: 'se terminaron',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Tiempo(mision: mision),
                        const SizedBox(height: 22),
                        Text('Desafío por desafío', style: AppText.serif(size: 17)),
                        const SizedBox(height: 4),
                        Text(
                          'Muchos fallos y muchas pistas en el mismo desafío suelen ser un '
                          'enunciado difícil de entender, no un visitante distraído.',
                          style: AppText.sans(size: 12.5),
                        ),
                        const SizedBox(height: 12),
                        if (datos.desafios.isEmpty)
                          Text(
                            'La misión no tiene desafíos cargados.',
                            style: AppText.sans(size: 13, color: AppColors.textoInactivo),
                          )
                        else
                          for (final desafio in datos.desafios) ...[
                            _FilaDesafio(desafio: desafio),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
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

/// El tiempo que tarda la gente, con la letra chica de cómo se midió.
class _Tiempo extends StatelessWidget {
  final UsoDeMision mision;

  const _Tiempo({required this.mision});

  @override
  Widget build(BuildContext context) {
    final medidas = mision.participacionesMedidas;
    final sinMedir = mision.participacionesSinMedir;
    final estimada = mision.duracionEstimada;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cuánto tardan', style: AppText.sans(size: 13.5, peso: FontWeight.w700)),
          const SizedBox(height: 6),
          if (mision.minutosMediana == null)
            Text(
              'Todavía no se puede medir: hace falta que alguien con cuenta '
              'termine la misión.',
              style: AppText.sans(size: 13),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(mision.tiempoEnTexto, style: AppText.serif(size: 24)),
                const SizedBox(width: 8),
                if (estimada != null)
                  Text('el museo estimó $estimada min', style: AppText.sans(size: 12.5)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Es la mediana de $medidas ${medidas == 1 ? 'recorrido' : 'recorridos'} '
              'terminados con cuenta. Mediana y no promedio: un solo recorrido que '
              'quedó abierto mucho tiempo alcanza para arruinar un promedio.',
              style: AppText.sans(size: 12.5),
            ),
          ],
          if (sinMedir > 0) ...[
            const SizedBox(height: 6),
            Text(
              sinMedir == 1
                  ? 'Un recorrido figura terminado más de un día después de empezar y no se cuenta acá.'
                  : '$sinMedir recorridos figuran terminados más de un día después de empezar y no se cuentan acá.',
              style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un desafío con sus números.
class _FilaDesafio extends StatelessWidget {
  final UsoDeDesafio desafio;

  const _FilaDesafio({required this.desafio});

  static const _nombres = {
    'pregunta_opcion_multiple': 'Opción múltiple',
    'respuesta_corta': 'Respuesta corta',
    'escaneo_objeto': 'Escaneo de pieza',
    'busqueda_guiada': 'Búsqueda guiada',
  };

  @override
  Widget build(BuildContext context) {
    final acierto = desafio.porcentajeAcierto;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${desafio.orden}.',
                style: AppText.sans(size: 13, color: AppColors.acento, peso: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  desafio.enunciado,
                  style: AppText.sans(size: 13.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _nombres[desafio.tipo] ?? desafio.tipo,
            style: AppText.sans(size: 11.5, color: AppColors.textoInactivo),
          ),
          const SizedBox(height: 10),
          if (desafio.intentos == 0 && desafio.pistas == 0)
            Text(
              'Nadie lo intentó todavía.',
              style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Pizca(
                  icono: Icons.check,
                  texto: acierto == null ? '—' : '$acierto%',
                  etiqueta: acierto == null
                      ? 'sin intentos'
                      : '$acierto por ciento de acierto',
                ),
                _Pizca(
                  icono: Icons.replay,
                  texto: '${desafio.intentos}',
                  etiqueta: '${desafio.intentos} intentos',
                ),
                if (desafio.fallos > 0)
                  _Pizca(
                    icono: Icons.close,
                    texto: '${desafio.fallos}',
                    etiqueta: '${desafio.fallos} fallidos',
                  ),
                if (desafio.pistas > 0)
                  _Pizca(
                    icono: Icons.lightbulb_outline,
                    texto: '${desafio.pistas}',
                    etiqueta: '${desafio.pistas} pistas pedidas',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// La cabecera que comparten las dos pantallas.
class _Cabecera extends StatelessWidget {
  final String titulo;
  final Future<void> Function() alActualizar;

  const _Cabecera({required this.titulo, required this.alActualizar});

  @override
  Widget build(BuildContext context) {
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
                  'Administración',
                  style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                ),
              ),
              IconButton(
                onPressed: () => alActualizar(),
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
              Text(titulo, style: AppText.serif(size: 24)),
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
      ],
    );
  }
}

/// Un mensaje en el medio con un botón para reintentar.
class _Centrado extends StatelessWidget {
  final String texto;
  final Future<void> Function() alReintentar;

  const _Centrado({required this.texto, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(texto, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => alReintentar(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.acento),
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

/// La fecha como se escribe acá: 16/11/2026.
String _fecha(DateTime f) =>
    '${f.day}/${f.month}/${f.year}';
