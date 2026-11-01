import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/insignia.dart';
import '../../sesion/sesion.dart';
import 'insignia_admin.dart';

/// Las insignias del museo, en orden alfabético (ADM19).
///
/// Se ven todas, las que se otorgan y las que están desactivadas, porque
/// esconder las desactivadas haría que el administrador creyera que se
/// perdieron.
class PantallaInsigniasAdmin extends StatefulWidget {
  const PantallaInsigniasAdmin({super.key});

  @override
  State<PantallaInsigniasAdmin> createState() => _PantallaInsigniasAdminState();
}

class _PantallaInsigniasAdminState extends State<PantallaInsigniasAdmin> {
  Future<List<Insignia>>? _insignias;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _insignias ??= _pedir();
  }

  Future<List<Insignia>> _pedir() {
    final pedido = listarInsignias(ProveedorSesion.de(context).token!);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  /// Abre el alta o la edición. Si hubo cambios, el listado se vuelve a pedir.
  Future<void> _abrir({Insignia? insignia}) async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaInsigniaAdmin(insignia: insignia)),
    );
    if (huboCambios == true) await _recargar();
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _insignias = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                  Text('Insignias', style: AppText.serif(size: 24)),
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
          'Nueva insignia',
          style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, ControlSesion sesion) {
    return FutureBuilder<List<Insignia>>(
      future: _insignias,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.acento));
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          // Un token vencido no se arregla reintentando: hay que volver a entrar.
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

        final insignias = snapshot.data ?? const <Insignia>[];
        if (insignias.isEmpty) {
          return _Centrado(
            texto: 'Todavía no hay insignias cargadas.\n'
                'Son los logros que los visitantes pueden ganar.',
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
            itemCount: insignias.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Tarjeta(
                insignia: insignias[i],
                alTocar: () => _abrir(insignia: insignias[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Insignia insignia;
  final VoidCallback alTocar;

  const _Tarjeta({required this.insignia, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final contenido = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hexagon_outlined,
                size: 22,
                color: insignia.activa ? AppColors.acento : AppColors.textoInactivo,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(insignia.nombre, style: AppText.serif(size: 17))),
              if (!insignia.activa)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.fondo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Text(
                    'No se otorga',
                    style: AppText.sans(size: 11.5, peso: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insignia.descripcion,
            style: AppText.sans(size: 13.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Cómo se gana, dicho en castellano. Lo primero que hay que
              // saber de una insignia recién creada es que todavía no se
              // puede ganar, y por eso ese caso va resaltado.
              Expanded(
                child: Text(
                  insignia.comoSeGana,
                  style: AppText.sans(
                    size: 12.5,
                    color: insignia.sePuedeGanar ? AppColors.textoInactivo : AppColors.media,
                    peso: insignia.sePuedeGanar ? FontWeight.w400 : FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                insignia.obtenidaPor == 0
                    ? 'Nadie la tiene'
                    : '${insignia.obtenidaPor} ${insignia.obtenidaPor == 1 ? 'la tiene' : 'la tienen'}',
                style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
              ),
            ],
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
