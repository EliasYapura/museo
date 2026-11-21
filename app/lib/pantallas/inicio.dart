import 'package:flutter/material.dart';

import '../estilo.dart';
import 'insignias.dart';
import 'misiones.dart';
import 'perfil.dart';

/// Pantalla principal: la barra de abajo y lo que se muestra en cada pestaña.
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
        children: const [PantallaMisiones(), PantallaInsignias(), PantallaPerfil()],
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
    // Cada ícono es una pestaña y van en el mismo orden que las pantallas del
    // IndexedStack: el índice sirve para las dos cosas.
    const items = [
      (Icons.explore_outlined, 'Misiones'),
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
                  activo: i == pestana,
                  alTocar: () => alElegir(i),
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
  final VoidCallback alTocar;

  const _ItemNav({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.acento : AppColors.textoInactivo;

    // excludeSemantics: sin esto el lector de pantalla anuncia el ícono y el
    // texto por separado, y la etiqueta se escucha dos veces.
    return Semantics(
      button: true,
      selected: activo,
      label: etiqueta,
      excludeSemantics: true,
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
    );
  }
}
