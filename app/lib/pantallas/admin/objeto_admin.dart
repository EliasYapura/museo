import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/objeto.dart';
import '../../sesion/sesion.dart';
import 'estado_objeto.dart';
import 'formulario_objeto.dart';
import 'identificador_objeto.dart';

/// Cargar una pieza del museo o editar una existente.
///
/// Con [objeto] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
///
/// Para editar no se vuelve a pedir la pieza: el listado ya trae todo lo que
/// el formulario necesita, así que la pantalla abre al instante con lo que ya
/// estaba a la vista.
class PantallaObjetoAdmin extends StatefulWidget {
  final Objeto? objeto;

  const PantallaObjetoAdmin({super.key, this.objeto});

  @override
  State<PantallaObjetoAdmin> createState() => _PantallaObjetoAdminState();
}

class _PantallaObjetoAdminState extends State<PantallaObjetoAdmin> {
  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  /// La pieza como quedó después de la última acción. Mientras sea null vale
  /// la que trajo el listado.
  Objeto? _actualizado;

  bool get _esAlta => widget.objeto == null;

  /// La versión más nueva que se conoce de la pieza.
  Objeto? get _pieza => _actualizado ?? widget.objeto;

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      final creado = await crearObjeto(sesion.token!, datos);
      _huboCambios = true;
      if (!mounted) return null;
      // Tras cargarla no tiene sentido quedarse en un formulario lleno: se
      // vuelve al listado, donde la pieza nueva ya aparece con su código.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pieza cargada con el código ${creado.codigo}.')),
      );
      return null;
    }

    final resultado = await editarObjeto(sesion.token!, widget.objeto!.id, datos);
    _huboCambios = _huboCambios || resultado.modificado;
    // Se guarda la pieza devuelta, que es lo que miran el título y el bloque
    // del identificador. El formulario no se rearma: perdería el aviso de que
    // se guardó.
    if (mounted) {
      setState(() {
        _actualizado = resultado.objeto;
      });
    }
    return resultado.modificado ? 'Cambios guardados.' : 'No había cambios para guardar.';
  }

  /// Da de baja o reactiva la pieza.
  Future<Objeto> _cambiarEstado({required bool activo}) async {
    final sesion = ProveedorSesion.de(context);
    final actualizado = await cambiarEstadoObjeto(sesion.token!, widget.objeto!.id, activo: activo);
    _huboCambios = true;
    if (mounted) setState(() => _actualizado = actualizado);
    return actualizado;
  }

  /// Borra la pieza. El bloque de estado se encarga de confirmar y de volver.
  Future<void> _borrar() async {
    final sesion = ProveedorSesion.de(context);
    await borrarObjeto(sesion.token!, widget.objeto!.id);
    _huboCambios = true;
  }

  /// Pide un código nuevo para la pieza y lo deja a la vista.
  Future<Objeto> _regenerarCodigo() async {
    final sesion = ProveedorSesion.de(context);
    final actualizado = await regenerarCodigo(sesion.token!, widget.objeto!.id);
    _huboCambios = true;
    if (mounted) setState(() => _actualizado = actualizado);
    return actualizado;
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
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
                        _esAlta ? 'Nuevo objeto' : 'Editar objeto',
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
                    Text(
                      _pieza?.nombre ?? 'Nueva pieza',
                      style: AppText.serif(size: 24),
                    ),
                    if (!_esAlta) ...[
                      const SizedBox(height: 6),
                      // El código no se edita acá: cambiarlo dejaría inservible
                      // la etiqueta que ya está puesta junto a la pieza.
                      Text(
                        _pieza!.codigo,
                        style: AppText.sans(size: 13, color: AppColors.acento).copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: CustomPaint(painter: GrecaPainter()),
                    ),
                    const SizedBox(height: 20),
                    FormularioObjeto(
                      objeto: widget.objeto,
                      alGuardar: _guardar,
                      textoBoton: _esAlta ? 'Cargar pieza' : 'Guardar cambios',
                    ),
                    // El identificador va aparte del formulario y sólo al
                    // editar: en el alta la pieza todavía no tiene código.
                    if (!_esAlta) ...[
                      const SizedBox(height: 30),
                      IdentificadorObjeto(
                        objeto: _pieza!,
                        alRegenerar: _regenerarCodigo,
                      ),
                      const SizedBox(height: 12),
                      EstadoObjeto(
                        objeto: _pieza!,
                        alCambiarEstado: _cambiarEstado,
                        alBorrar: _borrar,
                      ),
                    ],
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
