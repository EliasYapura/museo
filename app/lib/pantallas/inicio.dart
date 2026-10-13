import 'package:flutter/material.dart';

import '../estilo.dart';
import 'misiones.dart';
import 'perfil.dart';

/// Pantalla principal: la barra de abajo y lo que se muestra en cada pestaña.
///
/// Misiones y Perfil funcionan. Progreso e Insignias se ven apagadas y no
/// hacen nada todavía: Progreso es del Sprint 4 e Insignias del 5. Se dejan a
/// la vista para que la app se lea completa, pero deshabilitadas para no
/// prometer algo que no está.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack y no un simple if: así la lista de misiones no se vuelve
      // a pedir cada vez que se va a Perfil y se vuelve.
      body: IndexedStack(
        index: _pestana,
        children: const [PantallaMisiones(), PantallaPerfil()],
      ),
      bottomNavigationBar: _BarraNavegacion(
        pestana: _pestana,
        alElegir: (indice) => setState(() => _pestana = indice),
      ),
    );
  }
}

class _BarraNavegacion extends StatelessWidget {
  final int pestana;
  final ValueChanged<int> alElegir;

  const _BarraNavegacion({required this.pestana, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    // El tercer valor dice si la pestaña está habilitada.
    const items = [
      (Icons.explore_outlined, 'Misiones', true),
      (Icons.bar_chart_rounded, 'Progreso', false),
      (Icons.hexagon_outlined, 'Insignias', false),
      (Icons.person_outline, 'Perfil', true),
    ];
    // Perfil es el último ícono pero la segunda pantalla.
    const pantallaDe = {0: 0, 3: 1};

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
                  habilitado: items[i].$3,
                  activo: pantallaDe[i] == pestana,
                  alTocar: items[i].$3 ? () => alElegir(pantallaDe[i]!) : null,
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
  final bool habilitado;
  final VoidCallback? alTocar;

  const _ItemNav({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.habilitado,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.acento : AppColors.textoInactivo;

    return Semantics(
      button: habilitado,
      selected: activo,
      enabled: habilitado,
      label: etiqueta,
      excludeSemantics: true,
      child: Opacity(
        opacity: habilitado ? 1 : 0.4,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
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
            ),
          ),
        ),
      ),
    );
  }
}
