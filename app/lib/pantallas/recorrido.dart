import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/desafio.dart';
import '../modelos/desafio_jugable.dart';
import '../modelos/escaneo.dart';
import '../modelos/mision.dart';
import 'escaneo.dart';

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

  /// Qué desafío de la lista se está jugando.
  int _indice = 0;

  /// El escaneo acertado del desafío actual, si ya encontró la pieza. Vuelve a
  /// null al pasar al siguiente, porque cada desafío tiene la suya.
  ResultadoEscaneo? _escaneo;

  /// El desafío actual ya está resuelto y no hay otro al que pasar: era el
  /// último de la misión.
  bool _resuelto = false;

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

  /// Pasa al desafío siguiente, o marca el recorrido como terminado si éste
  /// era el último. Se llama siempre dentro de un setState.
  void _avanzar(int cuantos) {
    if (_indice + 1 < cuantos) {
      _indice++;
      _escaneo = null;
    } else {
      _resuelto = true;
    }
  }

  /// Abre la cámara y, si el código era el de la pieza, guarda lo que contó el
  /// museo sobre ella (VIS05).
  Future<void> _escanear(DesafioJugable desafio, int cuantos) async {
    final resultado = await Navigator.of(context).push<ResultadoEscaneo>(
      MaterialPageRoute(builder: (_) => PantallaEscaneo(desafio: desafio)),
    );
    // Null es haber salido de la cámara sin acertar: el desafío sigue igual.
    if (resultado == null || !mounted) return;

    setState(() {
      _escaneo = resultado;
      // Los desafíos de escaneo y búsqueda se terminan al encontrar la pieza.
      // Los que además preguntan algo siguen con la pregunta (VIS06).
      if (resultado.resuelto) _avanzar(cuantos);
    });
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
                  final desafio = desafios[_indice];
                  return _Desafio(
                    desafio: desafio,
                    escaneo: _escaneo,
                    resuelto: _resuelto,
                    posicion: _indice + 1,
                    total: desafios.length,
                    alEscanear: () => _escanear(desafio, desafios.length),
                    alAcertar: () => setState(() => _avanzar(desafios.length)),
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

  /// El escaneo acertado, si ya encontró la pieza.
  final ResultadoEscaneo? escaneo;

  /// Si el desafío ya está resuelto y era el último de la misión.
  final bool resuelto;

  /// Qué número de desafío es, contando desde 1. Es la posición en el
  /// recorrido y no el `orden` que guarda la base: así, si el administrador
  /// borró uno y quedó un hueco en la numeración, el visitante no lo ve.
  final int posicion;
  final int total;

  final VoidCallback alEscanear;
  final VoidCallback alAcertar;

  const _Desafio({
    required this.desafio,
    required this.escaneo,
    required this.resuelto,
    required this.posicion,
    required this.total,
    required this.alEscanear,
    required this.alAcertar,
  });

  /// Falta encontrar la pieza antes de poder resolver nada.
  bool get _faltaEscanear => desafio.requiereEscaneo && escaneo == null;

  /// Queda la pregunta por contestar.
  bool get _faltaResponder => !_faltaEscanear && desafio.tienePregunta && !resuelto;

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

        // Antes de escanear se dice qué buscar; después, lo que el museo
        // cuenta de la pieza encontrada, que es con lo que se responde.
        if (_faltaEscanear)
          _Pieza(desafio: desafio)
        else if (escaneo != null)
          _Encontrada(escaneo: escaneo!),

        // Al resolver un desafío del medio, la prueba de que estuvo bien es
        // que aparece el siguiente. En el último no aparece nada, así que si
        // no se dice acá el visitante se queda sin saber si acertó.
        if (resuelto) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18, color: AppColors.facil),
              const SizedBox(width: 8),
              Text(
                'Desafío resuelto.',
                style: AppText.sans(size: 14, color: AppColors.facil, peso: FontWeight.w700),
              ),
            ],
          ),
        ],

        const SizedBox(height: 26),

        if (_faltaResponder)
          // La clave hace que al cambiar de desafío el widget se rearme de
          // cero: sin ella, la opción marcada y lo escrito pasarían al
          // siguiente, que es otra pregunta.
          _Pregunta(
            key: ValueKey(desafio.id),
            desafio: desafio,
            alAcertar: alAcertar,
          )
        else
          _Accion(
            texto: _faltaEscanear ? 'Escanear el código' : 'Terminar la misión',
            // Escanear se puede; terminar la misión es VIS11.
            alTocar: _faltaEscanear ? alEscanear : null,
          ),
      ],
    );
  }
}

/// La pregunta del desafío y el botón para contestarla (VIS06).
///
/// Manda la respuesta al servidor, que es quien sabe cuál era la correcta.
/// Fallar no cuesta nada: se puede volver a intentar. Contar los intentos es
/// SIS02, del Sprint 4.
class _Pregunta extends StatefulWidget {
  final DesafioJugable desafio;

  /// Se llama cuando la respuesta estuvo bien. El recorrido avanza y este
  /// widget se va junto con el desafío.
  final VoidCallback alAcertar;

  const _Pregunta({super.key, required this.desafio, required this.alAcertar});

  @override
  State<_Pregunta> createState() => _PreguntaState();
}

class _PreguntaState extends State<_Pregunta> {
  final _escrita = TextEditingController();
  String? _elegida;
  bool _enviando = false;
  String _aviso = '';

  bool get _esOpcionMultiple => widget.desafio.tipo == TipoDesafio.preguntaOpcionMultiple;

  String get _respuesta => _esOpcionMultiple ? (_elegida ?? '') : _escrita.text.trim();

  @override
  void dispose() {
    _escrita.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _aviso = '';
    });
    try {
      final resultado = await responderDesafio(widget.desafio.id, _respuesta);
      if (!mounted) return;
      if (resultado.correcto) {
        widget.alAcertar();
        return;
      }
      setState(() => _aviso = _esOpcionMultiple
          ? 'Esa no es. Probá con otra.'
          : 'Esa no es. Fijate otra vez en lo que cuenta la pieza y probá de nuevo.');
    } on ErrorApi catch (error) {
      if (mounted) setState(() => _aviso = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al comprobar la respuesta: $error\n$pila');
      if (mounted) setState(() => _aviso = 'No se pudo comprobar la respuesta.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_esOpcionMultiple)
          for (final opcion in widget.desafio.opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Opcion(
                texto: opcion,
                elegida: _elegida == opcion,
                alTocar: _enviando ? null : () => setState(() => _elegida = opcion),
              ),
            )
        else
          TextField(
            controller: _escrita,
            enabled: !_enviando,
            style: AppText.sans(size: 15),
            // Sin estas dos, el teclado de Android "corrige" solo: pone la
            // mayúscula inicial y cambia palabras que no conoce. En un
            // desafío de comparación exacta eso haría fallar al visitante por
            // algo que no escribió él.
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_respuesta.isNotEmpty && !_enviando) _enviar();
            },
            decoration: InputDecoration(
              hintText: 'Escribí tu respuesta',
              hintStyle: AppText.sans(size: 15, color: AppColors.textoInactivo),
              filled: true,
              fillColor: AppColors.superficie,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.acento),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borde),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

        if (_aviso.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(_aviso, style: AppText.sans(size: 13.5, color: AppColors.dificil)),
        ],

        const SizedBox(height: 18),
        _Accion(
          texto: _enviando ? 'Comprobando…' : 'Responder',
          alTocar: _respuesta.isEmpty || _enviando ? null : _enviar,
        ),
      ],
    );
  }
}

/// Una de las opciones de una pregunta de opción múltiple.
class _Opcion extends StatelessWidget {
  final String texto;
  final bool elegida;
  final VoidCallback? alTocar;

  const _Opcion({required this.texto, required this.elegida, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: elegida ? AppColors.acento : AppColors.borde,
            width: elegida ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // El círculo marca cuál está elegida sin depender sólo del color
            // del borde, que en una pantalla al sol casi no se distingue.
            Icon(
              elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: elegida ? AppColors.acento : AppColors.textoInactivo,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: AppText.sans(size: 15))),
          ],
        ),
      ),
    );
  }
}

/// El botón grande del final de la pantalla.
class _Accion extends StatelessWidget {
  final String texto;

  /// Null lo deja apagado.
  final VoidCallback? alTocar;

  const _Accion({required this.texto, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final activo = alTocar != null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: alTocar,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.acento,
          disabledBackgroundColor: AppColors.superficie,
          disabledForegroundColor: AppColors.textoInactivo,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          texto,
          style: AppText.sans(
            size: 15,
            color: activo ? AppColors.fondo : AppColors.textoInactivo,
            peso: FontWeight.w700,
          ),
        ),
      ),
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
    return _Tarjeta(
      icono: Icons.place_outlined,
      titulo: desafio.pieza == null ? 'Dónde buscar' : 'Buscá esta pieza',
      children: [
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
    );
  }
}

/// Lo que el museo cuenta de la pieza, una vez encontrada.
///
/// Es la recompensa por haber caminado hasta la vitrina, y cuando el desafío
/// tiene una pregunta, es también con lo que se responde.
class _Encontrada extends StatelessWidget {
  final ResultadoEscaneo escaneo;

  const _Encontrada({required this.escaneo});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      icono: Icons.check_circle_outline,
      titulo: 'La encontraste',
      children: [
        if (escaneo.pieza != null) ...[
          Text(escaneo.pieza!, style: AppText.serif(size: 17)),
          const SizedBox(height: 8),
        ],
        if (escaneo.datoClave != null)
          Text(escaneo.datoClave!, style: AppText.sans(size: 14)),
      ],
    );
  }
}

/// El recuadro con el que se muestran la pieza buscada y la encontrada.
class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Widget> children;

  const _Tarjeta({required this.icono, required this.titulo, required this.children});

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
          Icon(icono, size: 20, color: AppColors.acento),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppText.sans(size: 12.5, color: AppColors.textoSecundario)
                      .copyWith(letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                ...children,
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
