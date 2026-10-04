// =============================================================================
//  Exploradores del Museo — Museo de La Plata
//  App del visitante.
//
//  Las misiones salen de la API (VIS01): GET /publico/misiones. La dirección
//  de la API y los estados de carga están en lib/api/cliente.dart.
// =============================================================================

import 'package:flutter/material.dart';

import 'estilo.dart';
import 'pantallas/misiones.dart';

void main() => runApp(const ExploradoresApp());

class ExploradoresApp extends StatelessWidget {
  const ExploradoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exploradores del Museo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.fondo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.acento,
          brightness: Brightness.dark,
          surface: AppColors.fondo,
        ),
      ),
      home: const PantallaMisiones(),
    );
  }
}
