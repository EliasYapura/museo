import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/insignia.dart';
import '../../modelos/mision_admin.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/condicion.js.
const maximoEscaneos = 1000;

/// Los tipos de condición que el evaluador sabe calcular.
///
/// La lista es cerrada a propósito: la columna es JSONB y la base aceptaría
/// cualquier forma, pero una regla que el evaluador no conoce sería una
/// insignia que no se otorga nunca sin que nadie entienda por qué. El
/// administrador elige de acá; no escribe JSON.
enum TipoCondicion { misionesCompletadas, misionSinPistas, escaneosSinError }

extension TipoCondicionX on TipoCondicion {
  String get valorApi => switch (this) {
        TipoCondicion.misionesCompletadas => 'misiones_completadas',
        TipoCondicion.misionSinPistas => 'mision_sin_pistas',
        TipoCondicion.escaneosSinError => 'escaneos_sin_error',
      };

  String get titulo => switch (this) {
        TipoCondicion.misionesCompletadas => 'Completar misiones',
        TipoCondicion.misionSinPistas => 'Completar una misión sin pistas',
        TipoCondicion.escaneosSinError => 'Escanear sin errores',
      };

  String get explicacion => switch (this) {
        TipoCondicion.misionesCompletadas =>
          'Se gana al terminar todas las misiones que elijas.',
        TipoCondicion.misionSinPistas =>
          'Se gana al terminar esa misión sin haber pedido ninguna pista.',
        TipoCondicion.escaneosSinError =>
          'Se gana al resolver esa cantidad de desafíos de escaneo acertando la '
              'pieza en el primer intento.',
      };

  static TipoCondicion? desdeApi(String? valor) {
    for (final tipo in TipoCondicion.values) {
      if (tipo.valorApi == valor) return tipo;
    }
    return null;
  }
}

/// Define cómo se gana una insignia (ADM20).
///
/// Al volver devuelve la insignia con la condición guardada, o null si no se
/// cambió nada.
class PantallaCondicionInsignia extends StatefulWidget {
  final Insignia insignia;

  const PantallaCondicionInsignia({super.key, required this.insignia});

  @override
  State<PantallaCondicionInsignia> createState() => _PantallaCondicionInsigniaState();
}

class _PantallaCondicionInsigniaState extends State<PantallaCondicionInsignia> {
  Future<List<MisionAdmin>>? _misiones;

  /// Null es "sin definir": la insignia existe pero todavía no se puede ganar.
  TipoCondicion? _tipo;

  /// Las misiones elegidas para el tipo de varias.
  final Set<int> _elegidas = {};

  /// La misión elegida para el tipo de una sola.
  int? _unaMision;

  late final TextEditingController _cantidad;

  bool _guardando = false;
  String _error = '';

  /// Errores que devolvió la API por campo. Ninguno de estos controles es un
  /// campo de texto, así que se muestran a mano al lado de lo que rechazaron.
  Map<String, String> _erroresApi = {};

  @override
  void initState() {
    super.initState();
    final condicion = widget.insignia.condicion;
    _tipo = TipoCondicionX.desdeApi(widget.insignia.tipoDeCondicion);

    // Se precarga lo que ya estaba guardado, para que entrar a mirar y salir
    // no pierda la configuración.
    _elegidas.addAll(((condicion['misiones'] as List?) ?? const []).whereType<int>());
    _unaMision = condicion['mision'] as int?;
    _cantidad = TextEditingController(text: '${condicion['cantidad'] ?? 10}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _misiones ??= _pedirMisiones();
  }

  Future<List<MisionAdmin>> _pedirMisiones() {
    final pedido = listarMisiones(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  void _alCambiar() {
    if (_erroresApi.isEmpty && _error.isEmpty) return;
    setState(() {
      _erroresApi = {};
      _error = '';
    });
  }

  /// Lo que se le manda a la API según el tipo elegido.
  Map<String, dynamic> _condicion() {
    return switch (_tipo) {
      null => const {},
      TipoCondicion.misionesCompletadas => {
          'tipo': _tipo!.valorApi,
          'misiones': _elegidas.toList(),
        },
      TipoCondicion.misionSinPistas => {'tipo': _tipo!.valorApi, 'mision': _unaMision},
      TipoCondicion.escaneosSinError => {
          'tipo': _tipo!.valorApi,
          // tryParse y no parse: si el campo quedó vacío o con letras, se
          // manda null y la API lo rechaza con su mensaje, igual que a
          // cualquier otro dato inválido.
          'cantidad': int.tryParse(_cantidad.text.trim()),
        },
    };
  }

  Future<void> _guardar() async {
    final sesion = ProveedorSesion.de(context);

    setState(() {
      _guardando = true;
      _error = '';
      _erroresApi = {};
    });
    try {
      final guardada = await guardarCondicionInsignia(
        sesion.token!,
        widget.insignia.id,
        _condicion(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(guardada);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tipo == null
                ? 'La insignia quedó sin condición: todavía no se puede ganar.'
                : 'Listo. Ya se puede ganar.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _erroresApi = error.errores;
        _error = error.errores.isEmpty ? error.mensaje : '';
      });
    } catch (error, pila) {
      debugPrint('Fallo al guardar la condición: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar la condición.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
                    tooltip: 'Volver',
                  ),
                  Expanded(
                    child: Text(
                      'Insignia',
                      style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  Text('Cómo se gana', style: AppText.serif(size: 24)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 18,
                    width: double.infinity,
                    child: CustomPaint(painter: GrecaPainter()),
                  ),
                  const SizedBox(height: 14),
                  Text(widget.insignia.nombre, style: AppText.sans(size: 13)),
                  const SizedBox(height: 22),

                  _Opcion(
                    titulo: 'Sin definir',
                    explicacion: 'La insignia queda cargada pero todavía no la gana nadie.',
                    elegida: _tipo == null,
                    alTocar: _guardando
                        ? null
                        : () {
                            setState(() => _tipo = null);
                            _alCambiar();
                          },
                  ),
                  for (final tipo in TipoCondicion.values)
                    _Opcion(
                      titulo: tipo.titulo,
                      explicacion: tipo.explicacion,
                      elegida: _tipo == tipo,
                      alTocar: _guardando
                          ? null
                          : () {
                              setState(() => _tipo = tipo);
                              _alCambiar();
                            },
                    ),

                  if (_erroresApi['tipo'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _erroresApi['tipo']!,
                      style: AppText.sans(size: 12.5, color: AppColors.dificil),
                    ),
                  ],

                  if (_tipo != null) ...[
                    const SizedBox(height: 22),
                    const Divider(color: AppColors.borde, height: 1),
                    const SizedBox(height: 20),
                    _detalleDelTipo(),
                  ],

                  const SizedBox(height: 26),
                  if (_error.isNotEmpty) ...[
                    Aviso(_error),
                    const SizedBox(height: 14),
                  ],
                  BotonPrincipal(
                    texto: 'Guardar la condición',
                    textoOcupado: 'Guardando…',
                    ocupado: _guardando,
                    alTocar: _guardar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalleDelTipo() {
    if (_tipo == TipoCondicion.escaneosSinError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaCampo('Cuántos escaneos', obligatorio: true),
          TextFormField(
            controller: _cantidad,
            enabled: !_guardando,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Entre 1 y $maximoEscaneos'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _alCambiar(),
          ),
          if (_erroresApi['cantidad'] != null) ...[
            const SizedBox(height: 6),
            Text(
              _erroresApi['cantidad']!,
              style: AppText.sans(size: 12.5, color: AppColors.dificil),
            ),
          ],
        ],
      );
    }

    // Los otros dos tipos eligen misiones. Se listan las cargadas en vez de
    // pedir un número: nadie se acuerda del id de una misión.
    final deVarias = _tipo == TipoCondicion.misionesCompletadas;
    final errorDeMisiones = _erroresApi[deVarias ? 'misiones' : 'mision'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaCampo(deVarias ? 'Qué misiones' : 'Qué misión', obligatorio: true),
        const SizedBox(height: 4),
        FutureBuilder<List<MisionAdmin>>(
          future: _misiones,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'No se pudieron cargar las misiones.',
                style: AppText.sans(size: 13.5, color: AppColors.dificil),
              );
            }

            final misiones = snapshot.data ?? const <MisionAdmin>[];
            if (misiones.isEmpty) {
              return Text(
                'No hay misiones cargadas todavía.',
                style: AppText.sans(size: 13.5),
              );
            }

            return Column(
              children: [
                for (final mision in misiones)
                  _FilaMision(
                    nombre: mision.nombre,
                    detalle: mision.activa ? 'Publicada' : 'En borrador',
                    elegida: deVarias
                        ? _elegidas.contains(mision.id)
                        : _unaMision == mision.id,
                    deVarias: deVarias,
                    alTocar: _guardando
                        ? null
                        : () {
                            setState(() {
                              if (deVarias) {
                                if (!_elegidas.remove(mision.id)) _elegidas.add(mision.id);
                              } else {
                                _unaMision = mision.id;
                              }
                            });
                            _alCambiar();
                          },
                  ),
              ],
            );
          },
        ),
        if (errorDeMisiones != null) ...[
          const SizedBox(height: 8),
          Text(errorDeMisiones, style: AppText.sans(size: 12.5, color: AppColors.dificil)),
        ],
      ],
    );
  }
}

/// Uno de los tipos de condición, para elegir.
class _Opcion extends StatelessWidget {
  final String titulo;
  final String explicacion;
  final bool elegida;
  final VoidCallback? alTocar;

  const _Opcion({
    required this.titulo,
    required this.explicacion,
    required this.elegida,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: elegida ? AppColors.acento : AppColors.borde),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: elegida ? AppColors.acento : AppColors.textoInactivo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: AppText.sans(
                        size: 14.5,
                        color: AppColors.textoPrimario,
                        peso: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(explicacion, style: AppText.sans(size: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una misión en la lista para elegir. Según el tipo se comporta como casilla
/// (varias) o como opción única.
class _FilaMision extends StatelessWidget {
  final String nombre;
  final String detalle;
  final bool elegida;
  final bool deVarias;
  final VoidCallback? alTocar;

  const _FilaMision({
    required this.nombre,
    required this.detalle,
    required this.elegida,
    required this.deVarias,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final marca = deVarias
        ? (elegida ? Icons.check_box : Icons.check_box_outline_blank)
        : (elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: elegida ? AppColors.acento : AppColors.borde),
          ),
          child: Row(
            children: [
              Icon(
                marca,
                size: 20,
                color: elegida ? AppColors.acento : AppColors.textoInactivo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: AppText.sans(size: 14, color: AppColors.textoPrimario),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(detalle, style: AppText.sans(size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
