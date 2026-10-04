import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../modelos/mision.dart';

/// Listado de misiones disponibles (VIS01).
///
/// Tiene estado porque los datos llegan de la API: hay un momento en el que
/// todavía no están, otro en el que puede haber fallado y otro con la lista.
class PantallaMisiones extends StatefulWidget {
  const PantallaMisiones({super.key});

  @override
  State<PantallaMisiones> createState() => _PantallaMisionesState();
}

class _PantallaMisionesState extends State<PantallaMisiones> {
  late Future<List<Mision>> _misiones;

  @override
  void initState() {
    super.initState();
    _misiones = obtenerMisiones();
  }

  Future<void> _recargar() async {
    final pedido = obtenerMisiones();
    setState(() => _misiones = pedido);
    // Deslizar para actualizar espera a que termine para sacar el indicador.
    await pedido.catchError((_) => <Mision>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Encabezado(),
            Expanded(
              child: FutureBuilder<List<Mision>>(
                future: _misiones,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _Centrado(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }

                  if (snapshot.hasError) {
                    return _Aviso(
                      titulo: 'No se pudieron cargar las misiones',
                      detalle: snapshot.error is ErrorApi
                          ? (snapshot.error as ErrorApi).mensaje
                          : 'Ocurrió un problema inesperado.',
                      alReintentar: _recargar,
                    );
                  }

                  final misiones = snapshot.data ?? const <Mision>[];
                  if (misiones.isEmpty) {
                    return _Aviso(
                      titulo: 'Todavía no hay misiones disponibles',
                      detalle:
                          'El museo está preparando los recorridos. Volvé a intentar más tarde.',
                      alReintentar: _recargar,
                    );
                  }

                  // RefreshIndicator necesita una lista que se pueda deslizar
                  // aunque entre entera en la pantalla: de ahí el physics.
                  return RefreshIndicator(
                    onRefresh: _recargar,
                    color: AppColors.acento,
                    backgroundColor: AppColors.superficie,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: misiones.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _TarjetaMision(mision: misiones[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BarraNavegacion(),
    );
  }
}

class _Centrado extends StatelessWidget {
  final Widget child;
  const _Centrado({required this.child});

  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// Pantalla de error o de lista vacía, con el botón de reintentar.
class _Aviso extends StatelessWidget {
  final String titulo;
  final String detalle;
  final Future<void> Function() alReintentar;

  const _Aviso({
    required this.titulo,
    required this.detalle,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return _Centrado(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppText.serif(size: 18),
            ),
            const SizedBox(height: 10),
            Text(detalle, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: alReintentar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(
                'Reintentar',
                style: AppText.sans(
                  size: 14,
                  color: AppColors.acento,
                  peso: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Encabezado: título + guarda ornamental + bajada
// -----------------------------------------------------------------------------
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Museo de La Plata',
            style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text('Exploradores del Museo', style: AppText.serif(size: 26)),
          const SizedBox(height: 14),

          // Guarda escalonada inspirada en la ornamentación americanista
          // de las salas del museo.
          SizedBox(
            height: 18,
            width: double.infinity,
            child: CustomPaint(painter: GrecaPainter()),
          ),

          const SizedBox(height: 18),
          Text(
            'Elegí una misión para empezar tu recorrido.',
            style: AppText.sans(size: 14.5),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Tarjeta de misión
// -----------------------------------------------------------------------------
class _TarjetaMision extends StatelessWidget {
  final Mision mision;
  const _TarjetaMision({required this.mision});

  @override
  Widget build(BuildContext context) {
    // Semantics agrupa la tarjeta en un solo nodo para lectores de pantalla,
    // en lugar de leer cada dato por separado (historia VIS13).
    return Semantics(
      button: true,
      label: '${mision.nombre}. ${mision.subtitulo}. '
          'Duración ${mision.duracionMin} minutos. '
          'Dificultad ${mision.dificultad.etiqueta}. '
          '${mision.puntos} puntos.',
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura con el ícono temático
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.fondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(painter: IconoPainter(mision.icono)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mision.nombre,
                    style: AppText.serif(size: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mision.subtitulo,
                    style:
                        AppText.sans(size: 12, color: AppColors.textoTerciario),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  _FilaMeta(mision: mision),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaMeta extends StatelessWidget {
  final Mision mision;
  const _FilaMeta({required this.mision});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('${mision.duracionMin} min', style: AppText.sans(size: 12.5)),
        const SizedBox(width: 14),

        // El color del punto es solo refuerzo: la dificultad siempre se
        // acompaña con texto, para no depender del color (accesibilidad).
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: mision.dificultad.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(mision.dificultad.etiqueta, style: AppText.sans(size: 12.5)),

        const Spacer(),
        Text(
          '${mision.puntos} pts',
          style: AppText.sans(
            size: 12.5,
            color: AppColors.acento,
            peso: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  Navegación inferior
//  Decorativa por ahora: Progreso es del Sprint 4, Insignias del 5 y Perfil
//  depende del inicio de sesión del visitante.
// -----------------------------------------------------------------------------
class _BarraNavegacion extends StatelessWidget {
  const _BarraNavegacion();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.explore_outlined, 'Misiones'),
      (Icons.bar_chart_rounded, 'Progreso'),
      (Icons.hexagon_outlined, 'Insignias'),
      (Icons.person_outline, 'Perfil'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navFondo,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                _ItemNav(
                  icono: items[i].$1,
                  etiqueta: items[i].$2,
                  activo: i == 0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool activo;

  const _ItemNav({
    required this.icono,
    required this.etiqueta,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.acento : AppColors.textoInactivo;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: AppText.sans(
            size: 11,
            color: color,
            peso: activo ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
