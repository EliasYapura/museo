import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/pista.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/pista.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const largoMaximoPista = 300;
const penalizacionMaxima = 1000;

/// Qué pasó en la hoja de carga, para que la pantalla sepa cómo seguir.
/// Cerrarla sin guardar no devuelve ninguno de los dos: devuelve null.
enum _Resultado { cambiada, sesionVencida }

/// Las pistas de un desafío (ADM13).
///
/// Cada pista es un texto y lo que cuesta pedirla. Se entregan en el orden en
/// que están cargadas, que lo asigna la API: la nueva va siempre al final.
///
/// Al volver devuelve true si hubo cambios, para que la pantalla del desafío
/// actualice la cuenta que muestra.
class PantallaPistasDesafio extends StatefulWidget {
  final int desafioId;

  /// El enunciado del desafío, para no perder de vista a cuál se le están
  /// cargando pistas.
  final String enunciado;

  const PantallaPistasDesafio({
    super.key,
    required this.desafioId,
    required this.enunciado,
  });

  @override
  State<PantallaPistasDesafio> createState() => _PantallaPistasDesafioState();
}

class _PantallaPistasDesafioState extends State<PantallaPistasDesafio> {
  Future<({int puntos, List<Pista> pistas})>? _datos;

  /// Se marca al guardar o borrar, para avisarle a la pantalla anterior que
  /// la cuenta de pistas que muestra quedó vieja.
  bool _huboCambios = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datos ??= _pedir();
  }

  Future<({int puntos, List<Pista> pistas})> _pedir() {
    final pedido = listarPistas(ProveedorSesion.de(context).token!, widget.desafioId);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _datos = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  /// Abre la hoja de carga: con [pista] en null es un alta.
  ///
  /// Es una hoja y no otra pantalla porque son dos campos: abrir una pantalla
  /// entera para eso haría perder de vista la lista que se está armando.
  Future<void> _abrir({Pista? pista, int? posicion, required int puntos}) async {
    final sesion = ProveedorSesion.de(context);

    final resultado = await showModalBottomSheet<_Resultado>(
      context: context,
      backgroundColor: AppColors.fondo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HojaPista(
        token: sesion.token!,
        desafioId: widget.desafioId,
        puntosDelDesafio: puntos,
        pista: pista,
        posicion: posicion,
      ),
    );
    if (!mounted) return;

    if (resultado == _Resultado.sesionVencida) {
      sesion.cerrarSesion();
      Navigator.of(context).pop(_huboCambios);
      return;
    }
    if (resultado == _Resultado.cambiada) {
      _huboCambios = true;
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<({int puntos, List<Pista> pistas})>(
            future: _datos,
            builder: (context, snapshot) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(_huboCambios),
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.textoPrimario,
                          tooltip: 'Volver',
                        ),
                        Expanded(
                          child: Text(
                            'Desafío',
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
                        Text('Pistas', style: AppText.serif(size: 24)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 18,
                          width: double.infinity,
                          child: CustomPaint(painter: GrecaPainter()),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.enunciado,
                          style: AppText.sans(size: 13),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
        floatingActionButton: FutureBuilder<({int puntos, List<Pista> pistas})>(
          future: _datos,
          builder: (context, snapshot) {
            final cargado = snapshot.data;
            // Sin los datos no se sabe cuántos puntos vale el desafío, que es
            // lo que la hoja muestra como referencia, así que no se ofrece
            // agregar hasta que la lista esté.
            if (cargado == null) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () => _abrir(puntos: cargado.puntos),
              backgroundColor: AppColors.acento,
              foregroundColor: AppColors.fondo,
              icon: const Icon(Icons.add),
              label: Text(
                'Agregar pista',
                style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<({int puntos, List<Pista> pistas})> snapshot,
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
          Navigator.of(context).pop(_huboCambios);
        });
      }
      return _Centrado(
        texto: error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
        alReintentar: _recargar,
      );
    }

    final datos = snapshot.data;
    final pistas = datos?.pistas ?? const <Pista>[];
    if (pistas.isEmpty) {
      return _Centrado(
        texto: 'Este desafío todavía no tiene pistas.\n'
            'Son opcionales: sin ellas, el visitante lo resuelve sin ayuda.',
        alReintentar: _recargar,
        // Acá no falló nada: no hay nada que reintentar, solo volver a mirar.
        textoBoton: 'Actualizar',
      );
    }

    final puntos = datos!.puntos;
    final descuentoTotal = pistas.fold(0, (suma, pista) => suma + pista.penalizacion);

    return RefreshIndicator(
      onRefresh: _recargar,
      color: AppColors.acento,
      backgroundColor: AppColors.superficie,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
        // Uno más que las pistas: el último es la nota del final.
        itemCount: pistas.length + 1,
        itemBuilder: (_, i) {
          if (i == pistas.length) {
            return _Nota(
              descuentoTotal: descuentoTotal,
              puntos: puntos,
              cuantas: pistas.length,
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Tarjeta(
              pista: pistas[i],
              indice: i,
              alTocar: () => _abrir(pista: pistas[i], posicion: i + 1, puntos: puntos),
            ),
          );
        },
      ),
    );
  }
}

/// La hoja donde se carga o se edita una pista.
class _HojaPista extends StatefulWidget {
  final String token;
  final int desafioId;

  /// Cuánto vale el desafío, para decidir con qué penalización tiene sentido
  /// cobrar la pista.
  final int puntosDelDesafio;

  /// La pista que se edita, o null si se está creando una.
  final Pista? pista;

  /// Qué lugar ocupa, para el título. Es la posición en la lista y no la
  /// columna orden: al borrar una, la base deja el hueco.
  final int? posicion;

  const _HojaPista({
    required this.token,
    required this.desafioId,
    required this.puntosDelDesafio,
    this.pista,
    this.posicion,
  });

  @override
  State<_HojaPista> createState() => _HojaPistaState();
}

class _HojaPistaState extends State<_HojaPista> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _texto;
  late final TextEditingController _penalizacion;

  bool _guardando = false;
  bool _borrando = false;
  String _error = '';

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  bool get _esAlta => widget.pista == null;
  bool get _ocupado => _guardando || _borrando;

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.pista?.texto ?? '');
    _penalizacion = TextEditingController(text: '${widget.pista?.penalizacion ?? 0}');
  }

  @override
  void dispose() {
    _texto.dispose();
    _penalizacion.dispose();
    super.dispose();
  }

  /// Al tocar algo se descartan los rechazos de la API: son de un intento
  /// anterior y seguirían apareciendo sobre un dato ya corregido.
  void _alEscribir() {
    if (_erroresApi.isEmpty && _error.isEmpty) return;
    setState(() {
      _erroresApi = {};
      _error = '';
    });
  }

  String? _validarTexto(String? valor) {
    if (_erroresApi['texto'] != null) return _erroresApi['texto'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El texto de la pista es obligatorio';
    if (texto.runes.length > largoMaximoPista) {
      return 'La pista no puede superar los $largoMaximoPista caracteres';
    }
    return null;
  }

  String? _validarPenalizacion(String? valor) {
    if (_erroresApi['penalizacion'] != null) return _erroresApi['penalizacion'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'La penalización es obligatoria';
    // Se revisa que sean sólo dígitos y no con tryParse: "10e2" o "+5" son
    // números para Dart pero no lo que esperamos acá.
    if (!RegExp(r'^\d+$').hasMatch(texto) || int.parse(texto) > penalizacionMaxima) {
      return 'La penalización tiene que ser un número entero entre 0 y $penalizacionMaxima';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = '';
    });

    final datos = {
      'texto': _texto.text.trim(),
      'penalizacion': int.parse(_penalizacion.text.trim()),
    };

    try {
      if (_esAlta) {
        await crearPista(widget.token, widget.desafioId, datos);
      } else {
        await editarPista(widget.token, widget.pista!.id, datos);
      }
      if (!mounted) return;
      Navigator.of(context).pop(_Resultado.cambiada);
      return;
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        Navigator.of(context).pop(_Resultado.sesionVencida);
        return;
      }
      setState(() {
        _erroresApi = error.errores;
        // Si la API explicó qué campo está mal, el mensaje va en el campo y
        // arriba no hace falta repetirlo.
        _error = error.errores.isEmpty ? error.mensaje : '';
      });
      // Vuelve a validar para que los campos muestren lo que rechazó la API.
      _formulario.currentState?.validate();
    } catch (error, pila) {
      debugPrint('Fallo al guardar la pista: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar la pista.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final confirmado = await _confirmarBorrado();
    if (confirmado != true || !mounted) return;

    setState(() {
      _borrando = true;
      _error = '';
    });
    try {
      await borrarPista(widget.token, widget.pista!.id);
      if (!mounted) return;
      Navigator.of(context).pop(_Resultado.cambiada);
      return;
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        Navigator.of(context).pop(_Resultado.sesionVencida);
        return;
      }
      setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al borrar la pista: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo borrar la pista.');
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  Future<bool?> _confirmarBorrado() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Borrar la pista?', style: AppText.serif(size: 19)),
        content: Text(
          'No se puede deshacer. Las demás pistas del desafío se siguen '
          'entregando en el mismo orden.',
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
              'Sí, borrar',
              style: AppText.sans(size: 14, color: AppColors.dificil, peso: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // El teclado tapa la hoja: este espacio la levanta justo lo que mide.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formulario,
          // Una vez que la hoja se envió, los mensajes se actualizan a medida
          // que se corrige, sin esperar a tocar el botón otra vez.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _esAlta ? 'Nueva pista' : 'Pista ${widget.posicion ?? ''}'.trim(),
                style: AppText.serif(size: 20),
              ),
              const SizedBox(height: 18),

              const EtiquetaCampo('Texto de la pista', obligatorio: true),
              TextFormField(
                controller: _texto,
                style: estiloCampo,
                decoration: decoracionCampo(pista: 'Está cerca de la ventana del patio'),
                maxLength: largoMaximoPista,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _alEscribir(),
                validator: _validarTexto,
              ),
              const SizedBox(height: 4),

              const EtiquetaCampo('Penalización', obligatorio: true),
              TextFormField(
                controller: _penalizacion,
                style: estiloCampo,
                decoration: decoracionCampo(pista: 'Entre 0 y $penalizacionMaxima'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _alEscribir(),
                validator: _validarPenalizacion,
              ),
              const SizedBox(height: 4),
              Text(
                'Lo que pierde el visitante por pedirla. 0 para una que no cuesta. '
                'El desafío vale ${widget.puntosDelDesafio} '
                '${widget.puntosDelDesafio == 1 ? 'punto' : 'puntos'}.',
                style: AppText.sans(size: 12.5),
              ),
              const SizedBox(height: 22),

              if (_error.isNotEmpty) ...[
                Aviso(_error),
                const SizedBox(height: 14),
              ],

              BotonPrincipal(
                texto: _esAlta ? 'Agregar pista' : 'Guardar cambios',
                textoOcupado: 'Guardando…',
                ocupado: _ocupado,
                alTocar: _guardar,
              ),

              // Borrar sólo al editar: en el alta no hay nada que borrar.
              if (!_esAlta) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _ocupado ? null : _borrar,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: _ocupado ? AppColors.textoInactivo : AppColors.dificil,
                    ),
                    label: Text(
                      _borrando ? 'Borrando…' : 'Borrar pista',
                      style: AppText.sans(
                        size: 13.5,
                        color: _ocupado ? AppColors.textoInactivo : AppColors.dificil,
                        peso: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una pista en la lista.
class _Tarjeta extends StatelessWidget {
  final Pista pista;

  /// Posición en la lista. Es lo que se muestra y no la columna orden de la
  /// base: al borrar una, la base deja el hueco (la 1, 2, 3 pasa a ser 1, 3).
  /// El visitante las recibe en fila, así que lo que importa es la posición.
  final int indice;

  final VoidCallback alTocar;

  const _Tarjeta({
    required this.pista,
    required this.indice,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              style: AppText.sans(size: 13, color: AppColors.acento, peso: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pista.texto, style: AppText.sans(size: 14, color: AppColors.textoPrimario)),
                const SizedBox(height: 8),
                Text(
                  pista.penalizacion == 0
                      ? 'Sin descuento'
                      : 'Descuenta ${pista.penalizacion} '
                          '${pista.penalizacion == 1 ? 'punto' : 'puntos'}',
                  style: AppText.sans(
                    size: 12.5,
                    color: pista.penalizacion == 0 ? AppColors.textoInactivo : AppColors.acento,
                    peso: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // La tarjeta entera abre la edición, igual que en los demás listados: en
    // un teléfono un botón al costado de cada fila no entra y se toca el
    // equivocado.
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: contenido,
    );
  }
}

/// La cuenta del final: cuánto descuentan todas las pistas juntas.
///
/// Importa porque el administrador carga las pistas de a una y no va sumando.
/// Si entre todas se comen los puntos del desafío, resolverlo con ayuda no
/// suma nada, que puede ser lo buscado o un descuido.
class _Nota extends StatelessWidget {
  final int descuentoTotal;
  final int puntos;
  final int cuantas;

  const _Nota({
    required this.descuentoTotal,
    required this.puntos,
    required this.cuantas,
  });

  @override
  Widget build(BuildContext context) {
    final seLoComen = descuentoTotal >= puntos && puntos > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: seLoComen ? AppColors.dificil : AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$cuantas ${cuantas == 1 ? 'pista' : 'pistas'}, '
            '$descuentoTotal ${descuentoTotal == 1 ? 'punto' : 'puntos'} '
            'de descuento en total. El desafío vale $puntos.',
            style: AppText.sans(size: 13),
          ),
          if (seLoComen) ...[
            const SizedBox(height: 6),
            Text(
              'Quien use todas las pistas no va a sumar nada por este desafío. '
              'El puntaje nunca baja de cero.',
              style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
            ),
          ],
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
