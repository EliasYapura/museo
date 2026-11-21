import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/categoria.dart';
import '../../modelos/objeto.dart';
import '../../sesion/sesion.dart';
import 'categorias_admin.dart';
import 'objeto_admin.dart';

/// Las piezas del museo, en el orden del recorrido.
///
/// Se pueden cargar, editar, ver el código QR y dar de baja desde acá.
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
  Future<({List<Categoria> categorias, int sinClasificar})>? _categorias;

  /// Qué filtro está puesto (ADM23): null es sin filtro, [sinCategoria] son
  /// las piezas sin clasificar, y un número es el id de una categoría.
  String? _filtro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _objetos ??= _pedir();
    _categorias ??= _pedirCategorias();
  }

  Future<List<Objeto>> _pedir() {
    final pedido = listarObjetos(ProveedorSesion.de(context).token!, categoria: _filtro);
    // El error se maneja en el FutureBuilder; esto solo evita que además se
    // reporte como no atendido.
    pedido.ignore();
    return pedido;
  }

  Future<({List<Categoria> categorias, int sinClasificar})> _pedirCategorias() {
    final pedido = listarCategorias(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  /// Cambia el filtro y vuelve a pedir la lista.
  ///
  /// El pedido se rehace contra la API en vez de filtrar lo que ya está en
  /// pantalla: con un acervo grande la lista sin filtrar no se trae entera, y
  /// filtrar acá daría resultados incompletos sin avisar.
  void _filtrarPor(String? filtro) {
    if (_filtro == filtro) return;
    setState(() {
      _filtro = filtro;
      _objetos = _pedir();
    });
  }

  /// Abre la administración de categorías.
  ///
  /// Al volver se recarga todo: crear, renombrar o borrar una categoría cambia
  /// el filtro de esta pantalla, y borrar una deja piezas sin clasificar.
  Future<void> _abrirCategorias() async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaCategoriasAdmin()),
    );
    if (huboCambios != true || !mounted) return;
    // Si el filtro puesto era una categoría que ya no existe, se vuelve a
    // "todas": filtrar por algo borrado dejaría la lista vacía sin explicación.
    if (_filtro != null && _filtro != sinCategoria) _filtro = null;
    await _recargar();
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
    // Las categorías se piden de nuevo junto con los objetos: clasificar una
    // pieza cambia las cuentas del filtro, y sin esto los números se quedaban
    // congelados en lo que valían al abrir la pantalla.
    final pedidoCategorias = _pedirCategorias();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _objetos = pedido;
      _categorias = pedidoCategorias;
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
                    onPressed: _abrirCategorias,
                    icon: const Icon(Icons.label_outline),
                    color: AppColors.acento,
                    tooltip: 'Categorías',
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
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FiltroDeCategoria(
                pedido: _categorias,
                elegido: _filtro,
                alElegir: _filtrarPor,
              ),
            ),
            const SizedBox(height: 14),
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
                    // Con un filtro puesto, la lista vacía no quiere decir que
                    // el museo no tenga piezas: quiere decir que ninguna entra
                    // en ese filtro. Ofrecer "Actualizar" ahí sería engañoso.
                    if (_filtro != null) {
                      return _Centrado(
                        texto: _filtro == sinCategoria
                            ? 'Todas las piezas están clasificadas.'
                            : 'Ninguna pieza está en esa categoría.',
                        alTocar: () async => _filtrarPor(null),
                        textoBoton: 'Ver todas',
                      );
                    }
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

          // La sala dice dónde está físicamente; la categoría, con qué otras
          // piezas se agrupa (ADM23). Van juntas y separadas por un punto
          // porque son dos formas de ubicar la misma pieza.
          Row(
            children: [
              Expanded(
                child: Text(
                  objeto.categoria == null
                      ? (objeto.sala ?? 'Sin sala')
                      : '${objeto.sala ?? 'Sin sala'} · ${objeto.categoria}',
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

/// El filtro por categoría del listado (ADM23).
///
/// Es una lista desplegable y no una tira de chips: un museo puede tener
/// decenas de disciplinas, y una tira obliga a recorrerla de punta a punta
/// para ver qué hay. El desplegable las muestra todas de una.
///
/// Se ofrecen TODAS las categorías, incluso las que no tienen ninguna pieza,
/// con su cuenta al lado. Esconder las vacías dejaba al administrador sin
/// saber qué categorías existen, que es justo lo que necesita para clasificar.
///
/// Mientras no llegan no se muestra nada: el filtro es una ayuda, y la lista
/// de abajo funciona igual sin él.
class _FiltroDeCategoria extends StatelessWidget {
  final Future<({List<Categoria> categorias, int sinClasificar})>? pedido;
  final String? elegido;
  final void Function(String?) alElegir;

  const _FiltroDeCategoria({
    required this.pedido,
    required this.elegido,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Categoria> categorias, int sinClasificar})>(
      future: pedido,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final datos = snapshot.data;
        if (datos == null || datos.categorias.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: elegido,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppColors.superficie,
              iconEnabledColor: AppColors.acento,
              items: [
                _opcion(null, 'Todas las categorías', elegido == null),
                for (final categoria in datos.categorias)
                  _opcion(
                    '${categoria.id}',
                    '${categoria.nombre} (${categoria.objetos})',
                    elegido == '${categoria.id}',
                  ),
                // Va al final y no entre las demás: es el cajón de lo que
                // falta ordenar, no una categoría más del museo.
                _opcion(
                  sinCategoria,
                  'Sin categoría (${datos.sinClasificar})',
                  elegido == sinCategoria,
                ),
              ],
              onChanged: alElegir,
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String?> _opcion(String? valor, String texto, bool elegido) {
    return DropdownMenuItem<String?>(
      value: valor,
      child: Text(
        texto,
        style: AppText.sans(
          size: 13.5,
          color: elegido ? AppColors.acento : AppColors.textoSecundario,
          peso: elegido ? FontWeight.w700 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
