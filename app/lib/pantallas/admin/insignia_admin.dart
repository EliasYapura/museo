import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/insignia.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';
import 'formulario_insignia.dart';

/// Crear una insignia o editar una existente (ADM19).
///
/// Con [insignia] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
class PantallaInsigniaAdmin extends StatefulWidget {
  final Insignia? insignia;

  const PantallaInsigniaAdmin({super.key, this.insignia});

  @override
  State<PantallaInsigniaAdmin> createState() => _PantallaInsigniaAdminState();
}

class _PantallaInsigniaAdminState extends State<PantallaInsigniaAdmin> {
  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  /// La insignia tal como está ahora. Cambia al activarla o desactivarla, que
  /// pasa en esta misma pantalla y no en el formulario.
  late Insignia? _insignia = widget.insignia;

  bool _cambiandoEstado = false;
  bool _borrando = false;
  String _error = '';

  bool get _esAlta => widget.insignia == null;
  bool get _ocupado => _cambiandoEstado || _borrando;

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      await crearInsignia(sesion.token!, datos);
      _huboCambios = true;
      if (!mounted) return null;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insignia creada. Falta definir cómo se gana.'),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }

    final guardada = await editarInsignia(sesion.token!, _insignia!.id, datos);
    _huboCambios = true;
    if (mounted) setState(() => _insignia = guardada);
    return 'Cambios guardados.';
  }

  /// Deja de otorgarla, o la vuelve a otorgar. No le quita nada a nadie.
  Future<void> _cambiarEstado(bool activa) async {
    final sesion = ProveedorSesion.de(context);

    setState(() {
      _cambiandoEstado = true;
      _error = '';
    });
    try {
      final cambiada = await cambiarActivaInsignia(sesion.token!, _insignia!.id, activa);
      if (!mounted) return;
      _huboCambios = true;
      setState(() => _insignia = cambiada);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activa
                ? 'La insignia se vuelve a otorgar.'
                : 'La insignia dejó de otorgarse. Quien ya la tenía la conserva.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(_huboCambios);
        return;
      }
      setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al cambiar el estado de la insignia: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo cambiar el estado.');
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  /// Borra la insignia, después de confirmar, y vuelve al listado.
  Future<void> _borrar() async {
    final sesion = ProveedorSesion.de(context);
    final confirmado = await _confirmarBorrado();
    if (confirmado != true || !mounted) return;

    setState(() {
      _borrando = true;
      _error = '';
    });
    try {
      final laTenian = await borrarInsignia(sesion.token!, _insignia!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            laTenian == 0
                ? 'Insignia borrada.'
                : 'Insignia borrada. Se la quitamos a $laTenian '
                    '${laTenian == 1 ? 'visitante' : 'visitantes'}.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(_huboCambios);
        return;
      }
      setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al borrar la insignia: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo borrar la insignia.');
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  /// Borrar una insignia no se deshace y, si alguien la ganó, se la saca. El
  /// diálogo lo dice con el número: sin eso, borrar sería a ciegas.
  Future<bool?> _confirmarBorrado() {
    final cuantos = _insignia!.obtenidaPor;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Borrar la insignia?', style: AppText.serif(size: 19)),
        content: Text(
          cuantos == 0
              ? 'No se puede deshacer. Todavía no la ganó nadie.'
              : 'No se puede deshacer, y $cuantos '
                  '${cuantos == 1 ? 'visitante que ya la ganó la va a perder' : 'visitantes que ya la ganaron la van a perder'}.\n\n'
                  'Si lo que querés es dejar de otorgarla, desactivala en vez '
                  'de borrarla: así quien la tiene la conserva.',
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
    final insignia = _insignia;

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
                        'Insignias',
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
                      _esAlta ? 'Nueva insignia' : 'Insignia',
                      style: AppText.serif(size: 24),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: CustomPaint(painter: GrecaPainter()),
                    ),
                    const SizedBox(height: 20),

                    // Que todavía no se pueda ganar no es un error: es el
                    // estado normal hasta que se le cargue una condición.
                    if (insignia != null && !insignia.sePuedeGanar) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.superficie,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borde),
                        ),
                        child: Text(
                          'Todavía no la puede ganar nadie: no tiene definido cómo '
                          'se obtiene.',
                          style: AppText.sans(size: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    FormularioInsignia(
                      insignia: insignia,
                      alGuardar: _guardar,
                      textoBoton: _esAlta ? 'Crear insignia' : 'Guardar cambios',
                    ),

                    // Desactivar y borrar sólo al editar: en el alta no hay
                    // nada que desactivar ni que borrar todavía.
                    if (!_esAlta) ...[
                      const SizedBox(height: 26),
                      if (_error.isNotEmpty) ...[
                        Aviso(_error),
                        const SizedBox(height: 12),
                      ],
                      const Divider(color: AppColors.borde, height: 1),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Se otorga',
                                  style: AppText.sans(
                                    size: 14,
                                    color: AppColors.textoPrimario,
                                    peso: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  insignia!.activa
                                      ? 'Los visitantes que cumplan la condición la ganan.'
                                      : 'Nadie nuevo la gana. Quien ya la tenía la conserva.',
                                  style: AppText.sans(size: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: insignia.activa,
                            onChanged: _ocupado ? null : _cambiarEstado,
                            activeThumbColor: AppColors.acento,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      const Divider(color: AppColors.borde, height: 1),
                      const SizedBox(height: 10),
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
                            _borrando ? 'Borrando…' : 'Borrar insignia',
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
            ],
          ),
        ),
      ),
    );
  }
}
