import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/objeto.dart';
import '../../sesion/sesion.dart';
import 'objeto_admin.dart';

/// Las piezas del museo, en el orden del recorrido.
///
/// Por ahora sólo se ven: cargar, editar, ver el código QR y dar de baja
/// llegan después.
///
/// En el panel web es una tabla de seis columnas. En un teléfono no entra, así
/// que cada pieza es una tarjeta y los datos se apilan.
class PantallaObjetosAdmin extends StatefulWidget {
  const PantallaObjetosAdmin({super.key});

  @override
  State<PantallaObjetosAdmin> createState() => _PantallaObjetosAdminState();
}

class _PantallaObjetosAdminState extends State<PantallaObjetosAdmin> {
  Future<List<Objeto>>? _objetos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _objetos ??= _pedir();
  }

  Future<List<Objeto>> _pedir() {
    final pedido = listarObjetos(ProveedorSesion.de(context).token!);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  /// Abre el alta o la edición. Si hubo cambios, el listado se vuelve a pedir.
  Future<void> _abrir({Objeto? objeto}) async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaObjetoAdmin(objeto: objeto)),
    );
    if (huboCambios == true) await _recargar();
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _objetos = pedido;
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
                  Text('Objetos', style: AppText.serif(size: 24)),
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
            Expanded(
              child: FutureBuilder<List<Objeto>>(
                future: _objetos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    // Un token vencido no se arregla reintentando: hay que
                    // volver a entrar.
                    if (error is ErrorApi && error.sesionVencida) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        sesion.cerrarSesion();
                        Navigator.of(context).pop();
                      });
                    }
                    return _Centrado(
                      texto: error is ErrorApi
                          ? error.mensaje
                          : 'Ocurrió un problema inesperado.',
                      alTocar: _recargar,
                    );
                  }

                  final objetos = snapshot.data ?? const <Objeto>[];
                  if (objetos.isEmpty) {
                    return _Centrado(
                      texto: 'Todavía no hay objetos cargados.',
                      alTocar: _recargar,
                      // Acá no falló nada: no hay nada que reintentar.
                      textoBoton: 'Actualizar',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _recargar,
                    color: AppColors.acento,
                    backgroundColor: AppColors.superficie,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: objetos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _Tarjeta(
                        objeto: objetos[i],
                        alTocar: () => _abrir(objeto: objetos[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        backgroundColor: AppColors.acento,
        foregroundColor: AppColors.fondo,
        icon: const Icon(Icons.add),
        label: Text(
          'Nuevo objeto',
          style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Objeto objeto;
  final VoidCallback alTocar;

  const _Tarjeta({required this.objeto, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    // Un objeto dado de baja se ve apagado, pero no se esconde: hay que poder
    // encontrarlo para reactivarlo.
    final color = objeto.activo ? AppColors.textoPrimario : AppColors.textoInactivo;

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
              Expanded(
                child: Text(
                  objeto.nombre,
                  style: AppText.serif(size: 17, color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _Estado(activo: objeto.activo),
            ],
          ),
          const SizedBox(height: 10),

          // El código es lo que está pegado en la vitrina, así que va en
          // monoespaciada: se lee carácter por carácter para compararlo.
          Text(
            objeto.codigo,
            style: AppText.sans(size: 13, color: AppColors.acento).copyWith(
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  objeto.sala ?? 'Sin sala',
                  style: AppText.sans(size: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  objeto.tipoIdentificador.etiqueta,
                  style: AppText.sans(size: 11, peso: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                objeto.desafios == 0
                    ? 'sin usar'
                    : '${objeto.desafios} ${objeto.desafios == 1 ? 'desafío' : 'desafíos'}',
                style: AppText.sans(
                  size: 12.5,
                  color: objeto.desafios == 0
                      ? AppColors.textoInactivo
                      : AppColors.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // La tarjeta entera abre la pieza, igual que en los otros listados: en un
    // teléfono un botón al costado de cada fila no entra y se toca el
    // equivocado.
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: contenido,
    );
  }
}

class _Estado extends StatelessWidget {
  final bool activo;
  const _Estado({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _Centrado extends StatelessWidget {
  final String texto;
  final Future<void> Function() alTocar;
  final String textoBoton;

  const _Centrado({
    required this.texto,
    required this.alTocar,
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
              onPressed: alTocar,
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
