import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/mision_admin.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';
import 'desafios_mision.dart';
import 'formulario_mision.dart';

/// Crear una misión o editar una existente.
///
/// Con [misionId] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
class PantallaMisionAdmin extends StatefulWidget {
  final int? misionId;
  final String? nombreConocido;

  const PantallaMisionAdmin({super.key, this.misionId, this.nombreConocido});

  @override
  State<PantallaMisionAdmin> createState() => _PantallaMisionAdminState();
}

class _PantallaMisionAdminState extends State<PantallaMisionAdmin> {
  Future<MisionAdmin?>? _mision;

  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  /// La misión como quedó después de la última acción: guardar, publicar o
  /// despublicar. Mientras sea null vale la que trajo la carga inicial.
  ///
  /// Se guarda acá en vez de volver a pedir la misión porque recargar manda al
  /// FutureBuilder de vuelta a "cargando" y en ese instante el formulario se
  /// destruye, perdiendo lo que se estuviera escribiendo.
  MisionAdmin? _actualizada;

  /// Publicando, despublicando o archivando.
  bool _ocupado = false;
  String _errorEstado = '';
  String _avisoEstado = '';

  bool get _esAlta => widget.misionId == null;

  /// La versión más nueva que se conoce de la misión.
  MisionAdmin? _ultima(MisionAdmin? cargada) => _actualizada ?? cargada;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mision ??= _pedir();
  }

  Future<MisionAdmin?> _pedir() {
    if (_esAlta) return Future.value(null);
    final pedido = obtenerMisionAdmin(ProveedorSesion.de(context).token!, widget.misionId!);
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _mision = pedido;
      // Recargar es justamente pedir el estado de verdad: lo que quedó de una
      // acción anterior ya no manda.
      _actualizada = null;
      _errorEstado = '';
      _avisoEstado = '';
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      final creada = await crearMision(sesion.token!, datos);
      _huboCambios = true;
      if (!mounted) return null;
      // Tras crearla no tiene sentido quedarse en un formulario vacío: se
      // vuelve al listado, donde la misión nueva ya aparece.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Misión “${creada.nombre}” creada como borrador.')),
      );
      return null;
    }

    final resultado = await editarMision(sesion.token!, widget.misionId!, datos);
    _huboCambios = _huboCambios || resultado.modificada;
    // No se reemplaza el future de la misión: hacerlo manda al FutureBuilder
    // de vuelta a "cargando" por un cuadro, y en ese instante el formulario se
    // destruye y se vuelve a crear, perdiendo el aviso de que se guardó.
    // Alcanza con quedarse con la misión que devolvió la API, que es lo que
    // usan el título y la sección de estado.
    if (mounted) {
      setState(() {
        _actualizada = resultado.mision;
      });
    }
    return resultado.modificada ? 'Cambios guardados.' : 'No había cambios para guardar.';
  }

  /// Abre los desafíos de la misión y, al volver, actualiza la cuenta.
  ///
  /// No se vuelve a armar la pantalla entera: se pide la misión y se guarda
  /// como [_actualizada], que es lo que miran el título y la sección de
  /// estado. Reemplazar el future destruiría el formulario.
  Future<void> _abrirDesafios(MisionAdmin mision) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDesafiosMision(
          misionId: mision.id,
          nombreConocido: mision.nombre,
        ),
      ),
    );
    if (!mounted) return;

    try {
      final fresca = await obtenerMisionAdmin(
        ProveedorSesion.de(context).token!,
        mision.id,
      );
      if (!mounted) return;
      // Si cambió la cantidad, el listado de misiones también la muestra y
      // tiene que recargarse al salir.
      if (fresca.desafios != mision.desafios) _huboCambios = true;
      setState(() => _actualizada = fresca);
    } catch (error) {
      // Es sólo refrescar un número: si falla, se queda el que había. Molestar
      // con un error acá sería peor que mostrar una cuenta vieja.
      debugPrint('No se pudo actualizar la cuenta de desafíos: $error');
    }
  }

  /// Publica o despublica, según cómo esté ahora.
  Future<void> _cambiarPublicacion(MisionAdmin mision) async {
    final sesion = ProveedorSesion.de(context);
    setState(() {
      _ocupado = true;
      _errorEstado = '';
      _avisoEstado = '';
    });
    try {
      final actualizada = await cambiarPublicacion(
        sesion.token!,
        mision.id,
        activa: !mision.activa,
      );
      _huboCambios = true;
      if (!mounted) return;
      setState(() {
        _actualizada = actualizada;
        _avisoEstado = actualizada.activa
            ? 'Misión publicada: ya la ven los visitantes.'
            : 'Misión despublicada: dejó de verse en la app.';
      });
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(_huboCambios);
        return;
      }
      // Si alguien borró el último desafío desde otra pantalla, la API
      // responde 409 y su mensaje ya explica qué falta. No se recarga la
      // misión para refrescar la cuenta porque eso destruiría el formulario;
      // el aviso alcanza para entender por qué no se publicó.
      setState(() => _errorEstado = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al cambiar la publicación: $error\n$pila');
      if (mounted) setState(() => _errorEstado = 'No se pudo cambiar el estado de la misión.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Archiva la misión, después de confirmar.
  Future<void> _archivar(MisionAdmin mision) async {
    final sesion = ProveedorSesion.de(context);
    final confirmado = await _confirmarArchivado(mision);
    if (confirmado != true || !mounted) return;

    setState(() {
      _ocupado = true;
      _errorEstado = '';
      _avisoEstado = '';
    });
    try {
      await archivarMision(sesion.token!, mision.id);
      if (!mounted) return;
      // Archivada deja de aparecer en el listado, así que no tiene sentido
      // quedarse en su pantalla.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Misión “${mision.nombre}” archivada.')),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(_huboCambios);
        return;
      }
      setState(() => _errorEstado = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al archivar la misión: $error\n$pila');
      if (mounted) setState(() => _errorEstado = 'No se pudo archivar la misión.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Archivar no se deshace desde la app, así que se pregunta antes. En el
  /// teléfono va en un diálogo y no en una fila de confirmación como el panel:
  /// el dedo pasa cerca de todo y conviene sacar el toque de la lista.
  Future<bool?> _confirmarArchivado(MisionAdmin mision) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Archivar la misión?', style: AppText.serif(size: 19)),
        content: Text(
          '“${mision.nombre}” va a dejar de aparecer en la administración y, si está '
          'publicada, los visitantes no la van a ver más.\n\n'
          'Sus desafíos y el avance de los visitantes no se borran.',
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
              'Sí, archivar',
              style: AppText.sans(size: 14, color: AppColors.dificil, peso: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
                        _esAlta ? 'Nueva misión' : 'Editar misión',
                        style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<MisionAdmin?>(
                  future: _mision,
                  builder: (context, snapshot) {
                    if (!_esAlta && snapshot.connectionState == ConnectionState.waiting) {
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
                          Navigator.of(context).pop(false);
                        });
                      }
                      return _ErrorCargando(
                        mensaje: error is ErrorApi
                            ? error.mensaje
                            : 'Ocurrió un problema inesperado.',
                        alReintentar: _recargar,
                      );
                    }

                    final mision = _ultima(snapshot.data);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        Text(
                          mision?.nombre ?? widget.nombreConocido ?? 'Nueva misión',
                          style: AppText.serif(size: 24),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 18,
                          width: double.infinity,
                          child: CustomPaint(painter: GrecaPainter()),
                        ),
                        const SizedBox(height: 20),
                        FormularioMision(
                          // La key fuerza a rearmar el formulario cuando la
                          // misión se recarga, para que los campos muestren lo
                          // último guardado.
                          key: ValueKey(mision?.id),
                          mision: mision,
                          alGuardar: _guardar,
                          textoBoton: _esAlta ? 'Crear misión' : 'Guardar cambios',
                        ),
                        // Publicar y archivar van aparte del formulario para
                        // que guardar los datos no cambie sin querer quién ve
                        // la misión. En el alta no aparecen: la misión todavía
                        // no existe.
                        if (mision != null) ...[
                          const SizedBox(height: 30),
                          _TarjetaDesafios(
                            cantidad: mision.desafios,
                            alTocar: () => _abrirDesafios(mision),
                          ),
                          const SizedBox(height: 12),
                          _SeccionEstado(
                            mision: mision,
                            ocupado: _ocupado,
                            error: _errorEstado,
                            aviso: _avisoEstado,
                            alPublicar: () => _cambiarPublicacion(mision),
                            alArchivar: () => _archivar(mision),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso a los desafíos de la misión, con cuántos tiene cargados.
class _TarjetaDesafios extends StatelessWidget {
  final int cantidad;
  final Future<void> Function() alTocar;

  const _TarjetaDesafios({required this.cantidad, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final vacia = cantidad == 0;

    return InkWell(
      onTap: () => alTocar(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
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
                    'Desafíos',
                    style: AppText.sans(size: 13.5, peso: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vacia
                        ? 'Todavía no tiene ninguno.'
                        : '$cantidad ${cantidad == 1 ? 'cargado' : 'cargados'}.',
                    style: AppText.sans(
                      size: 13,
                      color: vacia ? AppColors.textoInactivo : AppColors.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
          ],
        ),
      ),
    );
  }
}

/// Quién ve la misión y qué hacer con ella: publicarla, bajarla o archivarla.
class _SeccionEstado extends StatelessWidget {
  final MisionAdmin mision;
  final bool ocupado;
  final String error;
  final String aviso;
  final VoidCallback alPublicar;
  final VoidCallback alArchivar;

  const _SeccionEstado({
    required this.mision,
    required this.ocupado,
    required this.error,
    required this.aviso,
    required this.alPublicar,
    required this.alArchivar,
  });

  @override
  Widget build(BuildContext context) {
    final activa = mision.activa;
    // Despublicar nunca se bloquea: si algo sale mal en medio de una visita,
    // bajar la misión tiene que funcionar siempre. Publicar sí, cuando no hay
    // nada que resolver.
    final puede = mision.sePuedePublicar;

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
                child: Text(
                  'Estado',
                  style: AppText.sans(size: 13.5, peso: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: activa ? AppColors.facil : AppColors.borde),
                ),
                child: Text(
                  activa ? 'Publicada' : 'Borrador',
                  style: AppText.sans(
                    size: 11.5,
                    color: activa ? AppColors.facil : AppColors.textoSecundario,
                    peso: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activa
                ? 'Los visitantes la ven en el listado de misiones.'
                : 'Todavía no se ve en la app de los visitantes.',
            style: AppText.sans(size: 13),
          ),

          if (error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Aviso(error),
          ],
          if (aviso.isNotEmpty) ...[
            const SizedBox(height: 14),
            Aviso(aviso, esError: false),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              // Sin desafíos el botón queda apagado en vez de dejar que la API
              // lo rechace: es más claro enterarse antes de tocarlo.
              onPressed: ocupado || !puede ? null : alPublicar,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: puede ? AppColors.acento : AppColors.borde),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                ocupado ? 'Un momento…' : (activa ? 'Despublicar' : 'Publicar'),
                style: AppText.sans(
                  size: 14.5,
                  color: ocupado || !puede ? AppColors.textoInactivo : AppColors.acento,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!puede) ...[
            const SizedBox(height: 8),
            Text(
              'Para publicarla necesita al menos un desafío.',
              style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ocupado ? null : alArchivar,
              icon: Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: ocupado ? AppColors.textoInactivo : AppColors.dificil,
              ),
              label: Text(
                'Archivar misión',
                style: AppText.sans(
                  size: 13.5,
                  color: ocupado ? AppColors.textoInactivo : AppColors.dificil,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCargando extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() alReintentar;

  const _ErrorCargando({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(mensaje, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: alReintentar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
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
