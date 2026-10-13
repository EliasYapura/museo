import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../modelos/mision.dart';
import '../sesion/sesion.dart';

/// Dirección de la API.
///
/// Cambia según dónde corre la app, para no tener que editar el código al
/// pasar de una forma de probar a otra:
/// - En el navegador, localhost, igual que el panel.
/// - En el emulador de Android, 10.0.2.2: dentro del emulador, "localhost" es
///   el propio teléfono virtual, y 10.0.2.2 es la dirección con la que llega a
///   la computadora que lo hospeda.
/// - Desde un teléfono real, hay que pasar la IP de la PC en la red:
///   flutter run --dart-define=API_URL=http://192.168.0.10:3000
///
/// Se usa defaultTargetPlatform y no Platform de dart:io porque esa biblioteca
/// no existe cuando la app se compila para el navegador.
const _apiUrlDefinida = String.fromEnvironment('API_URL');

String get apiUrl {
  if (_apiUrlDefinida.isNotEmpty) return _apiUrlDefinida;
  if (kIsWeb) return 'http://localhost:3000';
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000'
      : 'http://localhost:3000';
}

/// Falla al hablar con la API, con un mensaje que se le puede mostrar al
/// visitante. El detalle técnico no le sirve a quien está en una sala del
/// museo con el teléfono en la mano.
///
/// [sesionVencida] marca el 401: la pantalla que lo reciba tiene que cerrar la
/// sesión en vez de ofrecer reintentar, porque reintentar con el mismo token
/// va a fallar siempre igual.
class ErrorApi implements Exception {
  final String mensaje;
  final bool sesionVencida;
  const ErrorApi(this.mensaje, {this.sesionVencida = false});

  @override
  String toString() => mensaje;
}

/// El plan gratuito de Render apaga el servicio tras unos minutos sin uso y el
/// primer pedido lo despierta, lo que puede tardar cerca de un minuto. Con una
/// espera corta, abrir la app por primera vez en el dia mostraria un error de
/// conexion que no es tal.
const _espera = Duration(seconds: 30);

/// Pide una dirección de la API y devuelve el JSON ya convertido.
///
/// [mensaje404] permite que cada pedido explique a su manera un 404; sin él,
/// se trata como cualquier otra respuesta inesperada.
Future<Map<String, dynamic>> _pedirJson(
  String ruta, {
  String? mensaje404,
  String? token,
  String metodo = 'GET',
  Map<String, dynamic>? cuerpo,
}) async {
  final http.Response respuesta;
  try {
    final uri = Uri.parse('$apiUrl$ruta');
    final cabeceras = {
      if (cuerpo != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final pedido = metodo == 'POST'
        ? http.post(uri, headers: cabeceras, body: cuerpo == null ? null : jsonEncode(cuerpo))
        : http.get(uri, headers: cabeceras);
    respuesta = await pedido.timeout(_espera);
  } catch (_) {
    // Servidor apagado, sin red, se agotó la espera o, en el navegador, un
    // bloqueo por CORS: para el visitante son todos el mismo problema.
    throw const ErrorApi('No se pudo conectar con el museo. Revisá tu conexión.');
  }

  if (respuesta.statusCode == 401) {
    throw const ErrorApi('Tu sesión venció. Ingresá de nuevo.', sesionVencida: true);
  }
  if (respuesta.statusCode == 404 && mensaje404 != null) throw ErrorApi(mensaje404);
  if (respuesta.statusCode != 200) {
    // Cuando la API rechaza el pedido (credenciales equivocadas, cuenta
    // desactivada) su mensaje explica el motivo y es mejor que uno genérico.
    // Cuando falla ella misma, no: "Error interno del servidor" no le dice
    // nada a quien está en una sala del museo.
    final suyo = respuesta.statusCode < 500 ? _mensajeDeError(respuesta) : null;
    throw ErrorApi(suyo ?? 'El museo no está respondiendo. Probá de nuevo en un rato.');
  }

  try {
    // utf8.decode y no respuesta.body: sin esto los acentos y las eñes
    // llegan rotos, porque body asume latin-1 cuando la respuesta no declara
    // el juego de caracteres.
    return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// El campo `error` del cuerpo, si la respuesta trae uno legible.
String? _mensajeDeError(http.Response respuesta) {
  try {
    final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final mensaje = cuerpo is Map ? cuerpo['error'] : null;
    return mensaje is String && mensaje.isNotEmpty ? mensaje : null;
  } catch (_) {
    return null;
  }
}

/// POST /auth/login — devuelve el token y los datos de quien entró.
Future<(String, Usuario)> autenticar(String email, String password) async {
  final cuerpo = await _pedirJson(
    '/auth/login',
    metodo: 'POST',
    cuerpo: {'email': email, 'password': password},
  );
  try {
    return (
      cuerpo['token'] as String,
      Usuario.desdeJson(cuerpo['usuario'] as Map<String, dynamic>),
    );
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// GET /auth/perfil — sirve para comprobar que un token guardado sigue valiendo.
Future<Usuario> obtenerPerfil(String token) async {
  final cuerpo = await _pedirJson('/auth/perfil', token: token);
  try {
    return Usuario.desdeJson(cuerpo['usuario'] as Map<String, dynamic>);
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// Cuántas misiones y objetos hay cargados, para la portada de administración.
/// Son las mismas rutas del panel, así que exigen token de administrador.
Future<({int misiones, int publicadas, int objetos})> obtenerResumen(String token) async {
  final misiones = await _pedirJson('/misiones', token: token);
  final objetos = await _pedirJson('/objetos', token: token);
  try {
    final lista = misiones['misiones'] as List;
    return (
      misiones: lista.length,
      publicadas: lista.where((m) => (m as Map)['activa'] == true).length,
      objetos: (objetos['objetos'] as List).length,
    );
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// GET /publico/misiones — las misiones publicadas (VIS01).
Future<List<Mision>> obtenerMisiones() async {
  final cuerpo = await _pedirJson('/publico/misiones');
  try {
    return (cuerpo['misiones'] as List)
        .map((json) => Mision.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// GET /publico/misiones/:id — el detalle de una misión (VIS03).
Future<Mision> obtenerMision(int id) async {
  final cuerpo = await _pedirJson(
    '/publico/misiones/$id',
    // La misión existía cuando se abrió el listado: si ahora no está, es
    // porque el museo la bajó mientras tanto.
    mensaje404: 'Esta misión ya no está disponible.',
  );
  try {
    return Mision.desdeJson(cuerpo['mision'] as Map<String, dynamic>);
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}
