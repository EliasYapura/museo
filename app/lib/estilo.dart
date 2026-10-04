// Paleta, tipografias y los dibujos a mano de la app.
//
// Se separo de main.dart al conectar la app con la API (VIS01): el archivo
// unico de la maqueta ya no daba abasto.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Icono tematico de la miniatura de cada mision. Mientras las misiones no
/// tengan imagen cargada, se elige uno segun el id (VIS01).
enum IconoMision { cristal, sauropodo, amonite, perezoso }

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
