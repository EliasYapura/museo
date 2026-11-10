import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/categoria.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/categoria.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const largoMaximoNombreCategoria = 80;

/// Qué pasó en la hoja de carga, para que la pantalla sepa cómo seguir.
/// Cerrarla sin guardar no devuelve ninguno de los dos: devuelve null.
enum _Resultado { cambiada, sesionVencida }

/// Las categorías con las que el museo clasifica su acervo (ADM23).
///
/// A diferencia de las salas, que son el edificio y se cargan en la base, acá
/// se pueden crear, renombrar y borrar: cada museo ordena lo suyo como quiere
/// y eso se revisa seguido.
///
/// Al volver devuelve true si hubo cambios, para que el listado de objetos
/// recargue sus filtros.
class PantallaCategoriasAdmin extends StatefulWidget {
  const PantallaCategoriasAdmin({super.key});

  @override
  State<PantallaCategoriasAdmin> createState() => _PantallaCategoriasAdminState();
}

class _PantallaCategoriasAdminState extends State<PantallaCategoriasAdmin> {
  Future<({List<Categoria> categorias, int sinClasificar})>? _datos;

  bool _huboCambios = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datos ??= _pedir();
  }

  Future<({List<Categoria> categorias, int sinClasificar})> _pedir() {
    final pedido = listarCategorias(ProveedorSesion.de(context).token!);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolvería el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _datos = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  /// Abre la hoja de carga: con [categoria] en null es un alta.
  Future<void> _abrir({Categoria? categoria}) async {
    final sesion = ProveedorSesion.de(context);

    final resultado = await showModalBottomSheet<_Resultado>(
      context: context,
      backgroundColor: AppColors.fondo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HojaCategoria(token: sesion.token!, categoria: categoria),
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
          child: Column(
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
                        'Objetos',
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
                    Text('Categorías', style: AppText.serif(size: 24)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: CustomPaint(painter: GrecaPainter()),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Con estas se agrupan las piezas del museo, aunque estén en '
                      'salas distintas.',
                      style: AppText.sans(size: 13),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(child: _contenido(context, sesion)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrir(),
          backgroundColor: AppColors.acento,
          foregroundColor: AppColors.fondo,
          icon: const Icon(Icons.add),
          label: Text(
            'Nueva categoría',
            style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, ControlSesion sesion) {
    return FutureBuilder<({List<Categoria> categorias, int sinClasificar})>(
      future: _datos,
      builder: (context, snapshot) {
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
        final categorias = datos?.categorias ?? const <Categoria>[];
        if (categorias.isEmpty) {
          return _Centrado(
            texto: 'El museo todavía no tiene categorías.\n'
                'Sin ellas las piezas se cargan igual, pero no se pueden agrupar.',
            alReintentar: _recargar,
            // Acá no falló nada: no hay nada que reintentar, solo volver a mirar.
            textoBoton: 'Actualizar',
          );
        }

        return RefreshIndicator(
          onRefresh: _recargar,
          color: AppColors.acento,
          backgroundColor: AppColors.superficie,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
            // Una más que las categorías: la última es la nota de las sueltas.
            itemCount: categorias.length + 1,
            itemBuilder: (_, i) {
              if (i == categorias.length) {
                return _SinClasificar(cuantas: datos?.sinClasificar ?? 0);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Tarjeta(
                  categoria: categorias[i],
                  alTocar: () => _abrir(categoria: categorias[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// La hoja donde se carga o se edita una categoría.
class _HojaCategoria extends StatefulWidget {
  final String token;

  /// La categoría que se edita, o null si se está creando una.
  final Categoria? categoria;

  const _HojaCategoria({required this.token, this.categoria});

  @override
  State<_HojaCategoria> createState() => _HojaCategoriaState();
}

class _HojaCategoriaState extends State<_HojaCategoria> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombre;

  bool _guardando = false;
  bool _borrando = false;
  String _error = '';

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  bool get _esAlta => widget.categoria == null;
  bool get _ocupado => _guardando || _borrando;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.categoria?.nombre ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
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

  String? _validarNombre(String? valor) {
    if (_erroresApi['nombre'] != null) return _erroresApi['nombre'];
    final nombre = (valor ?? '').trim();
    if (nombre.isEmpty) return 'El nombre es obligatorio';
    if (nombre.runes.length > largoMaximoNombreCategoria) {
      return 'El nombre no puede superar los $largoMaximoNombreCategoria caracteres';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = '';
    });

    final datos = {'nombre': _nombre.text.trim()};

    try {
      if (_esAlta) {
        await crearCategoria(widget.token, datos);
      } else {
        await editarCategoria(widget.token, widget.categoria!.id, datos);
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
      // Vuelve a validar para que el campo muestre lo que rechazó la API.
      _formulario.currentState?.validate();
    } catch (error, pila) {
      debugPrint('Fallo al guardar la categoría: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar la categoría.');
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
      await borrarCategoria(widget.token, widget.categoria!.id);
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
      debugPrint('Fallo al borrar la categoría: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo borrar la categoría.');
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  /// El aviso antes de borrar.
  ///
  /// Decir cuántas piezas quedan sueltas es lo importante: borrar una
  /// categoría no borra nada del acervo, pero eso no es obvio, y alguien que
  /// crea lo contrario no va a tocar el botón.
  Future<bool?> _confirmarBorrado() {
    final piezas = widget.categoria?.objetos ?? 0;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Borrar la categoría?', style: AppText.serif(size: 19)),
        content: Text(
          piezas == 0
              ? 'No hay ninguna pieza clasificada con ella, así que no cambia nada más.'
              : 'Las $piezas ${piezas == 1 ? 'pieza que la tiene' : 'piezas que la tienen'} '
                  'no se ${piezas == 1 ? 'borra' : 'borran'}: '
                  '${piezas == 1 ? 'queda' : 'quedan'} sin categoría y '
                  '${piezas == 1 ? 'se le' : 'se les'} puede asignar otra después.',
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
    final piezas = widget.categoria?.objetos ?? 0;

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
                _esAlta ? 'Nueva categoría' : 'Editar categoría',
                style: AppText.serif(size: 20),
              ),
              const SizedBox(height: 18),

              const EtiquetaCampo('Nombre', obligatorio: true),
              TextFormField(
                controller: _nombre,
                style: estiloCampo,
                decoration: decoracionCampo(pista: 'Paleontología'),
                maxLength: largoMaximoNombreCategoria,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _alEscribir(),
                validator: _validarNombre,
              ),
              const SizedBox(height: 4),
              Text(
                _esAlta
                    ? 'La disciplina o el tema con el que se agrupan las piezas.'
                    : 'Cambiarle el nombre no desclasifica nada: las piezas '
                        'siguen en esta categoría.',
                style: AppText.sans(size: 12.5),
              ),
              const SizedBox(height: 22),

              if (_error.isNotEmpty) ...[
                Aviso(_error),
                const SizedBox(height: 14),
              ],

              BotonPrincipal(
                texto: _esAlta ? 'Crear categoría' : 'Guardar cambios',
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
                      _borrando
                          ? 'Borrando…'
                          : piezas == 0
                              ? 'Borrar categoría'
                              : 'Borrar categoría ($piezas ${piezas == 1 ? 'pieza' : 'piezas'})',
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

/// Una categoría en la lista.
class _Tarjeta extends StatelessWidget {
  final Categoria categoria;
  final VoidCallback alTocar;

  const _Tarjeta({required this.categoria, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final vacia = categoria.objetos == 0;

    final contenido = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoria.nombre,
                  style: AppText.sans(
                    size: 14.5,
                    color: AppColors.textoPrimario,
                    peso: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  vacia
                      ? 'Ninguna pieza'
                      : '${categoria.objetos} ${categoria.objetos == 1 ? 'pieza' : 'piezas'}',
                  style: AppText.sans(
                    size: 12.5,
                    color: vacia ? AppColors.textoInactivo : AppColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
        ],
      ),
    );

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: contenido,
    );
  }
}

/// Cuántas piezas quedaron sin clasificar.
///
/// Va al final de la lista y no como una categoría más: no es una forma de
/// ordenar el acervo, es lo que falta ordenar.
class _SinClasificar extends StatelessWidget {
  final int cuantas;

  const _SinClasificar({required this.cuantas});

  @override
  Widget build(BuildContext context) {
    if (cuantas == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borde),
        ),
        child: Text(
          'Todas las piezas del museo están clasificadas.',
          style: AppText.sans(size: 13),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Text(
        'Hay $cuantas ${cuantas == 1 ? 'pieza' : 'piezas'} sin categoría. '
        '${cuantas == 1 ? 'Se encuentra' : 'Se encuentran'} filtrando por '
        '"Sin categoría" en el listado de objetos.',
        style: AppText.sans(size: 13),
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
