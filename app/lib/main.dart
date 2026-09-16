// =============================================================================
//  Exploradores del Museo — Museo de La Plata
//  Pantalla principal (Home): listado de misiones disponibles.
//
//  ALCANCE: solo la capa visual. No hay navegación, estado ni llamadas a la API;
//  los datos son constantes locales. Corresponde a las historias VIS01 y VIS02.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const ExploradoresApp());

// =============================================================================
//  PALETA
//  Fondo oscuro: la app se usa recorriendo salas con iluminación tenue, así que
//  reduce el encandilamiento. El ocre proviene de las guardas americanistas que
//  decoran las salas del museo.
// =============================================================================
class AppColors {
  static const fondo = Color(0xFF12211F);
  static const superficie = Color(0xFF1B2E2B);
  static const borde = Color(0xFF2C4440);
  static const navFondo = Color(0xFF0E1B19);

  static const textoPrimario = Color(0xFFF1EDE4);
  static const textoSecundario = Color(0xFF9DB0AA);
  static const textoTerciario = Color(0xFF8CA39C);
  static const textoInactivo = Color(0xFF7C918B);

  static const acento = Color(0xFFD9A441); // ocre dorado
  static const acentoGuarda = Color(0x8CD9A441); // acento al 55%
  static const acentoSepta = Color(0xF2D9A441); // acento al 95%
  static const facil = Color(0xFF7FA88A);
  static const media = Color(0xFFD9A441);
  static const dificil = Color(0xFFB5533C);
}

// =============================================================================
//  TIPOGRAFÍA
//  Serif para títulos (evoca las fichas de especímenes del museo).
//  Sans para la interfaz.
// =============================================================================
class AppText {
  static TextStyle serif({required double size, Color? color}) =>
      GoogleFonts.bitter(
        fontSize: size,
        color: color ?? AppColors.textoPrimario,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle sans({
    required double size,
    Color? color,
    FontWeight peso = FontWeight.w400,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color ?? AppColors.textoSecundario,
        fontWeight: peso,
        height: 1.3,
      );
}

// =============================================================================
//  MODELO (solo para maquetar — luego vendrá de la API)
// =============================================================================
enum Dificultad { facil, media, dificil }

extension DificultadX on Dificultad {
  String get etiqueta => switch (this) {
        Dificultad.facil => 'Fácil',
        Dificultad.media => 'Media',
        Dificultad.dificil => 'Difícil',
      };

  Color get color => switch (this) {
        Dificultad.facil => AppColors.facil,
        Dificultad.media => AppColors.media,
        Dificultad.dificil => AppColors.dificil,
      };
}

/// Ícono temático de la miniatura de cada misión.
enum IconoMision { cristal, sauropodo, amonite, perezoso }

class Mision {
  final String nombre;
  final String sala;
  final int duracionMin;
  final Dificultad dificultad;
  final int puntos;
  final IconoMision icono;

  const Mision({
    required this.nombre,
    required this.sala,
    required this.duracionMin,
    required this.dificultad,
    required this.puntos,
    required this.icono,
  });
}

/// Contenido real del Museo de La Plata (misiones MIS-01 a MIS-04).
const misionesDemo = <Mision>[
  Mision(
    nombre: 'Los guardianes del tiempo',
    sala: 'La Tierra · Planta baja',
    duracionMin: 20,
    dificultad: Dificultad.facil,
    puntos: 40,
    icono: IconoMision.cristal,
  ),
  Mision(
    nombre: 'El gigante de Pittsburgh',
    sala: 'Tiempo y Materia · Planta baja',
    duracionMin: 15,
    dificultad: Dificultad.facil,
    puntos: 30,
    icono: IconoMision.sauropodo,
  ),
  Mision(
    nombre: 'Cazadores de fósiles',
    sala: 'Era Mesozoica · Planta baja',
    duracionMin: 25,
    dificultad: Dificultad.media,
    puntos: 70,
    icono: IconoMision.amonite,
  ),
  Mision(
    nombre: 'La era de los gigantes',
    sala: 'Era Cenozoica · Planta baja',
    duracionMin: 25,
    dificultad: Dificultad.media,
    puntos: 70,
    icono: IconoMision.perezoso,
  ),
];

// =============================================================================
//  APP
// =============================================================================
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
      home: const PantallaPrincipal(),
    );
  }
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Encabezado(),
            const _FilaFiltros(),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: misionesDemo.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _TarjetaMision(mision: misionesDemo[i]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BarraNavegacion(),
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
//  Filtros por planta (estructura real del museo)
// -----------------------------------------------------------------------------
class _FilaFiltros extends StatelessWidget {
  const _FilaFiltros();

  @override
  Widget build(BuildContext context) {
    const filtros = ['Todas', 'Planta baja', 'Planta alta'];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filtros.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _Chip(texto: filtros[i], activo: i == 0),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final bool activo;
  const _Chip({required this.texto, required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: activo ? AppColors.acento : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: activo ? null : Border.all(color: AppColors.borde, width: 1.4),
      ),
      child: Text(
        texto,
        style: AppText.sans(
          size: 13.5,
          color: activo ? AppColors.fondo : AppColors.textoSecundario,
          peso: activo ? FontWeight.w700 : FontWeight.w400,
        ),
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
      label: '${mision.nombre}. ${mision.sala}. '
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
                    mision.sala,
                    style:
                        AppText.sans(size: 12, color: AppColors.textoTerciario),
                    maxLines: 1,
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

// =============================================================================
//  GUARDA ESCALONADA (greca americanista)
// =============================================================================
class GrecaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = AppColors.acentoGuarda
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.miter;

    const anchoModulo = 34.0;
    final path = Path();

    // Se repite el módulo hasta cubrir todo el ancho disponible.
    for (double x = 0; x < size.width; x += anchoModulo) {
      path.moveTo(x, 14);
      path.lineTo(x, 8);
      path.lineTo(x + 6, 8);
      path.lineTo(x + 6, 3);
      path.lineTo(x + 14, 3);
      path.lineTo(x + 14, 8);
      path.lineTo(x + 20, 8);
      path.lineTo(x + 20, 14);
      path.lineTo(x + 28, 14);
      path.lineTo(x + 28, 8);
      path.lineTo(x + 34, 8);
    }

    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, pincel);
  }

  @override
  bool shouldRepaint(covariant GrecaPainter oldDelegate) => false;
}

// =============================================================================
//  ÍCONOS TEMÁTICOS DE LAS MISIONES
//  Se dibujan con CustomPaint en lugar de usar imágenes: pesan menos, escalan
//  sin pérdida y mantienen un trazo uniforme entre todos.
// =============================================================================
class IconoPainter extends CustomPainter {
  final IconoMision tipo;
  IconoPainter(this.tipo);

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = AppColors.acento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final relleno = Paint()
      ..color = AppColors.acento
      ..style = PaintingStyle.fill;

    switch (tipo) {
      case IconoMision.cristal:
        _cristal(canvas, size, trazo);
        break;
      case IconoMision.sauropodo:
        _sauropodo(canvas, size, relleno);
        break;
      case IconoMision.amonite:
        _amonite(canvas, size, trazo);
        break;
      case IconoMision.perezoso:
        _perezoso(canvas, size, relleno);
        break;
    }
  }

  /// Geoda / cristal — Sala La Tierra.
  void _cristal(Canvas canvas, Size s, Paint p) {
    final c = Offset(s.width / 2, s.height / 2);
    const r = 26.0;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.87, c.dy - r * 0.5)
      ..lineTo(c.dx + r * 0.87, c.dy + r * 0.5)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.87, c.dy + r * 0.5)
      ..lineTo(c.dx - r * 0.87, c.dy - r * 0.5)
      ..close();
    canvas.drawPath(path, p);

    // Aristas internas
    canvas.drawLine(Offset(c.dx, c.dy - r), c, p);
    canvas.drawLine(c, Offset(c.dx + r * 0.87, c.dy - r * 0.5), p);
    canvas.drawLine(c, Offset(c.dx - r * 0.87, c.dy - r * 0.5), p);
    canvas.drawLine(c, Offset(c.dx, c.dy + r), p);
  }

  /// Saurópodo (Diplodocus) — Sala Tiempo y Materia.
  void _sauropodo(Canvas canvas, Size s, Paint relleno) {
    final o = Offset(s.width / 2 - 48, s.height / 2 - 48);

    Paint grosor(double w) => Paint()
      ..color = AppColors.acento
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // Cuello
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + 62, o.dy + 46)
        ..quadraticBezierTo(o.dx + 74, o.dy + 32, o.dx + 78, o.dy + 22),
      grosor(7),
    );
    // Cabeza
    canvas.drawCircle(Offset(o.dx + 80, o.dy + 20), 4.6, relleno);
    // Cola
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + 28, o.dy + 50)
        ..quadraticBezierTo(o.dx + 13, o.dy + 44, o.dx + 5, o.dy + 50),
      grosor(6),
    );
    // Cuerpo
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(o.dx + 48, o.dy + 52), width: 42, height: 19),
      relleno,
    );
    // Patas
    final patas = grosor(6.5);
    canvas.drawLine(
        Offset(o.dx + 38, o.dy + 60), Offset(o.dx + 37, o.dy + 74), patas);
    canvas.drawLine(
        Offset(o.dx + 57, o.dy + 60), Offset(o.dx + 58, o.dy + 74), patas);
  }

  /// Amonite — Era Mesozoica. Espiral logarítmica r = r0 · e^(k·θ).
  void _amonite(Canvas canvas, Size s, Paint p) {
    final c = Offset(s.width / 2, s.height / 2);
    const vueltas = 2.75;
    const k = 0.30;
    const rMax = 30.0;
    const pasos = 200;

    const tMax = vueltas * 2 * math.pi;
    final r0 = rMax / math.exp(k * tMax); // normaliza el radio final

    final path = Path();
    final puntos = <Offset>[];
    for (var i = 0; i <= pasos; i++) {
      final t = tMax * i / pasos;
      final r = r0 * math.exp(k * t);
      final a = t - 1.2; // rotación inicial
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      puntos.add(pt);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, p);

    // Septas: divisiones de las cámaras, sobre el tramo exterior.
    final septa = Paint()
      ..color = AppColors.acentoSepta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (var i = 0; i < 6; i++) {
      final idx = ((puntos.length - 1) * (0.55 + 0.44 * i / 5)).round();
      final ext = puntos[idx];
      final int_ = Offset(
        c.dx + (ext.dx - c.dx) * 0.45,
        c.dy + (ext.dy - c.dy) * 0.45,
      );
      canvas.drawLine(int_, ext, septa);
    }
  }

  /// Perezoso gigante (Megaterio) — Era Cenozoica.
  void _perezoso(Canvas canvas, Size s, Paint relleno) {
    final o = Offset(s.width / 2 - 48, s.height / 2 - 48);

    Paint grosor(double w) => Paint()
      ..color = AppColors.acento
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(o.dx + 46, o.dy + 50), width: 44, height: 34),
      relleno,
    );
    canvas.drawCircle(Offset(o.dx + 70, o.dy + 32), 9, relleno);

    final patas = grosor(8);
    canvas.drawLine(
        Offset(o.dx + 36, o.dy + 66), Offset(o.dx + 34, o.dy + 80), patas);
    canvas.drawLine(
        Offset(o.dx + 58, o.dy + 66), Offset(o.dx + 60, o.dy + 80), patas);

    // Brazo con garra
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + 25, o.dy + 58)
        ..quadraticBezierTo(o.dx + 10, o.dy + 64, o.dx + 8, o.dy + 76),
      grosor(7),
    );
  }

  @override
  bool shouldRepaint(covariant IconoPainter oldDelegate) =>
      oldDelegate.tipo != tipo;
}
