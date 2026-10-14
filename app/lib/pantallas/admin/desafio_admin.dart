import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/desafio.dart';
import '../../sesion/sesion.dart';
import 'formulario_desafio.dart';

/// Crear un desafío para una misión o editar uno existente.
///
/// Con [desafio] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
///
/// Para editar no se vuelve a pedir el desafío: el listado ya trae todo lo que
/// el formulario necesita, así que la pantalla abre al instante con lo que ya
/// estaba a la vista.
class PantallaDesafioAdmin extends StatefulWidget {
  final int misionId;
  final Desafio? desafio;

  const PantallaDesafioAdmin({super.key, required this.misionId, this.desafio});

  @override
  State<PantallaDesafioAdmin> createState() => _PantallaDesafioAdminState();
}

class _PantallaDesafioAdminState extends State<PantallaDesafioAdmin> {
  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  /// El orden del desafío, que se muestra en el título al editar.
  int? _orden;

  bool get _esAlta => widget.desafio == null;

  @override
  void initState() {
    super.initState();
    _orden = widget.desafio?.orden;
  }

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      await crearDesafio(sesion.token!, widget.misionId, datos);
      _huboCambios = true;
      if (!mounted) return null;
      // Tras crearlo no tiene sentido quedarse en un formulario lleno: se
      // vuelve al listado, donde el desafío nuevo ya aparece al final.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desafío agregado al final de la misión.')),
      );
      return null;
    }

    await editarDesafio(sesion.token!, widget.desafio!.id, datos);
    _huboCambios = true;
    // A diferencia de las misiones, la API de desafíos no avisa si hubo
    // cambios de verdad, así que el aviso no puede distinguirlo.
    return 'Cambios guardados.';
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
                        'Desafíos',
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
                      _esAlta ? 'Nuevo desafío' : 'Desafío ${_orden ?? ''}'.trim(),
                      style: AppText.serif(size: 24),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: CustomPaint(painter: GrecaPainter()),
                    ),
                    const SizedBox(height: 20),
                    FormularioDesafio(
                      desafio: widget.desafio,
                      alGuardar: _guardar,
                      textoBoton: _esAlta ? 'Agregar desafío' : 'Guardar cambios',
                    ),
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
