import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/objeto.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Qué hacer con una pieza: darla de baja, reactivarla o borrarla, y en qué
/// desafíos se usa.
///
/// Los usos no son un dato de adorno: una pieza que algún desafío usa no se
/// puede borrar, y esta lista es la que explica por qué.
class EstadoObjeto extends StatefulWidget {
  final Objeto objeto;

  /// Da de baja o reactiva, y devuelve la pieza actualizada.
  final Future<Objeto> Function({required bool activo}) alCambiarEstado;

  /// Borra la pieza. Si la API la rechaza, lanza el ErrorApi.
  final Future<void> Function() alBorrar;

  const EstadoObjeto({
    super.key,
    required this.objeto,
    required this.alCambiarEstado,
    required this.alBorrar,
  });

  @override
  State<EstadoObjeto> createState() => _EstadoObjetoState();
}

class _EstadoObjetoState extends State<EstadoObjeto> {
  Future<List<UsoDeObjeto>>? _usos;

  /// Cuántos desafíos la usan según lo último que se cargó. Mientras no se
  /// sepa vale la cuenta que trajo el listado.
  int? _cantidadUsos;

  bool _ocupado = false;
  String _error = '';
  String _aviso = '';

  int get _usosConocidos => _cantidadUsos ?? widget.objeto.desafios;
  bool get _sePuedeBorrar => _usosConocidos == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usos ??= _pedirUsos();
  }

  Future<List<UsoDeObjeto>> _pedirUsos() {
    final pedido = listarDesafiosDeObjeto(ProveedorSesion.de(context).token!, widget.objeto.id);
    pedido.ignore();
    // La cuenta se corrige con lo que conteste la API, que es más nuevo que lo
    // que trajo el listado.
    pedido.then((usos) {
      if (mounted) setState(() => _cantidadUsos = usos.length);
    }, onError: (_, __) {});
    return pedido;
  }

  Future<void> _cambiarEstado() async {
    final sesion = ProveedorSesion.de(context);
    setState(() {
      _ocupado = true;
      _error = '';
      _aviso = '';
    });
    try {
      final actualizado = await widget.alCambiarEstado(activo: !widget.objeto.activo);
      if (!mounted) return;
      setState(() {
        _aviso = actualizado.activo
            ? 'Pieza reactivada: vuelve a ofrecerse para desafíos nuevos.'
            : 'Pieza dada de baja. Los desafíos que ya la usan siguen funcionando.';
      });
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al cambiar el estado de la pieza: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo cambiar el estado de la pieza.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _borrar() async {
    final sesion = ProveedorSesion.de(context);
    final confirmado = await _confirmarBorrado();
    if (confirmado != true || !mounted) return;

    setState(() {
      _ocupado = true;
      _error = '';
      _aviso = '';
    });
    try {
      await widget.alBorrar();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pieza “${widget.objeto.nombre}” borrada.')),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(true);
        return;
      }
      // Si alguien agregó un desafío con esta pieza mientras tanto, la API la
      // rechaza y su mensaje dice cuántos la usan. Se vuelven a pedir los usos
      // para que la lista deje de mentir.
      setState(() {
        _error = error.mensaje;
        _usos = _pedirUsos();
      });
    } catch (error, pila) {
      debugPrint('Fallo al borrar la pieza: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo borrar la pieza.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool?> _confirmarBorrado() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Borrar la pieza?', style: AppText.serif(size: 19)),
        content: Text(
          '“${widget.objeto.nombre}” se borra de la base y no se puede deshacer.\n\n'
          'Si la pieza sigue en el museo y sólo querés dejar de usarla, dale de '
          'baja en vez de borrarla.',
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
    final activo = widget.objeto.activo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Estado', style: AppText.sans(size: 13.5, peso: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: activo ? AppColors.facil : AppColors.borde),
                ),
                child: Text(
                  activo ? 'Activo' : 'Dado de baja',
                  style: AppText.sans(
                    size: 11.5,
                    color: activo ? AppColors.facil : AppColors.textoSecundario,
                    peso: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activo
                ? 'Se puede elegir al armar un desafío.'
                : 'No se ofrece para desafíos nuevos. Los que ya la usan siguen funcionando.',
            style: AppText.sans(size: 13),
          ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Aviso(_error),
          ],
          if (_aviso.isNotEmpty) ...[
            const SizedBox(height: 14),
            Aviso(_aviso, esError: false),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _ocupado ? null : _cambiarEstado,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _ocupado ? AppColors.borde : AppColors.acento),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _ocupado ? 'Un momento…' : (activo ? 'Dar de baja' : 'Reactivar'),
                style: AppText.sans(
                  size: 14.5,
                  color: _ocupado ? AppColors.textoInactivo : AppColors.acento,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 16),

          Text('Dónde se usa', style: AppText.sans(size: 13.5, peso: FontWeight.w700)),
          const SizedBox(height: 8),
          _listaDeUsos(),

          const SizedBox(height: 18),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              // Una pieza en uso no se puede borrar: la clave foránea de la
              // base lo impide y dejaría desafíos apuntando a la nada.
              onPressed: _ocupado || !_sePuedeBorrar ? null : _borrar,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: _ocupado || !_sePuedeBorrar
                    ? AppColors.textoInactivo
                    : AppColors.dificil,
              ),
              label: Text(
                'Borrar pieza',
                style: AppText.sans(
                  size: 13.5,
                  color: _ocupado || !_sePuedeBorrar
                      ? AppColors.textoInactivo
                      : AppColors.dificil,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!_sePuedeBorrar)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                'No se puede borrar mientras algún desafío la use. Dale de baja.',
                style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listaDeUsos() {
    return FutureBuilder<List<UsoDeObjeto>>(
      future: _usos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            'Buscando…',
            style: AppText.sans(size: 13, color: AppColors.textoInactivo),
          );
        }
        if (snapshot.hasError) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  'No se pudo averiguar en qué desafíos se usa.',
                  style: AppText.sans(size: 13),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _usos = _pedirUsos()),
                child: Text(
                  'Reintentar',
                  style: AppText.sans(size: 13, color: AppColors.acento, peso: FontWeight.w700),
                ),
              ),
            ],
          );
        }

        final usos = snapshot.data ?? const <UsoDeObjeto>[];
        if (usos.isEmpty) {
          return Text(
            'Ningún desafío la usa todavía.',
            style: AppText.sans(size: 13, color: AppColors.textoInactivo),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final uso in usos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uso.enunciado, style: AppText.sans(size: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      uso.misionArchivada
                          ? '${uso.mision} · archivada'
                          : uso.mision,
                      style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
