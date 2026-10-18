import 'package:flutter/material.dart';

import '../estilo.dart';
import '../modelos/mision.dart';

/// Cómo terminó la misión (VIS11).
///
/// Reemplaza a la pantalla del recorrido en vez de apilarse encima: si se
/// apilara, el botón atrás de Android devolvería a un recorrido ya terminado,
/// con el último desafío resuelto y nada que hacer.
///
/// El resultado no se guarda en ningún lado: volver a empezar la misma misión
/// arranca de cero. Guardarlo en progreso_misiones es SIS03, del Sprint 4.
class PantallaResultado extends StatelessWidget {
  final Mision mision;

  /// Lo que el visitante ganó en el recorrido.
  final int puntos;

  /// Lo que valía la misión entera, sumando los desafíos que se jugaron.
  final int puntosPosibles;

  /// Cuántos desafíos tenía la misión. Hoy se resuelven todos: no se puede
  /// saltear ninguno ni terminar a medias, así que llegar acá es haberlos
  /// resuelto todos. Abandonar a mitad de camino es SIS03.
  final int desafios;

  const PantallaResultado({
    super.key,
    required this.mision,
    required this.puntos,
    required this.puntosPosibles,
    required this.desafios,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          children: [
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.acento),
                ),
                child: CustomPaint(painter: IconoPainter(mision.icono)),
              ),
            ),
            const SizedBox(height: 26),

            Text(
              'Misión cumplida',
              textAlign: TextAlign.center,
              style: AppText.serif(size: 27),
            ),
            const SizedBox(height: 8),
            Text(
              mision.nombre,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 15, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(painter: GrecaPainter()),
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borde),
              ),
              child: Column(
                children: [
                  Text(
                    '$puntos',
                    style: AppText.serif(size: 54).copyWith(color: AppColors.acento),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    puntos == 1 ? 'punto' : 'puntos',
                    style: AppText.sans(size: 15, color: AppColors.acento),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'de $puntosPosibles posibles',
                    style: AppText.sans(size: 13.5, color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borde),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: AppColors.facil),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      desafios == 1
                          ? 'Resolviste el único desafío de la misión.'
                          : 'Resolviste los $desafios desafíos de la misión.',
                      style: AppText.sans(size: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // popUntil y no pop: entre el listado y acá quedó el detalle
                // de la misión, y volver al listado es salir de los dos.
                onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.acento,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Volver a las misiones',
                  style: AppText.sans(size: 15, color: AppColors.fondo, peso: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
