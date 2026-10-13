// =============================================================================
//  Exploradores del Museo — Museo de La Plata
//  App del visitante y del equipo del museo.
//
//  Las misiones salen de la API (VIS01) y se recorren sin cuenta. Iniciar
//  sesión es lo que distingue al administrador, que además puede cargar
//  contenido desde el teléfono.
// =============================================================================

import 'package:flutter/material.dart';

import 'estilo.dart';
import 'pantallas/inicio.dart';
import 'sesion/sesion.dart';

void main() => runApp(const ExploradoresApp());

class ExploradoresApp extends StatefulWidget {
  const ExploradoresApp({super.key});

  @override
  State<ExploradoresApp> createState() => _ExploradoresAppState();
}

class _ExploradoresAppState extends State<ExploradoresApp> {
  final _sesion = ControlSesion();

  @override
  void initState() {
    super.initState();
    // Si quedó una sesión guardada de la vez anterior, se recupera al abrir.
    _sesion.recuperar();
  }

  @override
  void dispose() {
    _sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProveedorSesion(
      control: _sesion,
      child: MaterialApp(
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
        home: const PantallaInicio(),
      ),
    );
  }
}
