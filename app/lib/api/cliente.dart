import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../modelos/desafio.dart';
import '../modelos/desafio_jugable.dart';
import '../modelos/escaneo.dart';
import '../modelos/mision.dart';
import '../modelos/mision_admin.dart';
import '../modelos/objeto.dart';
import '../modelos/sala.dart';
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
/// [errores] trae los rechazos por campo que devuelve la API
/// (`{ "nombre": "El nombre es obligatorio" }`), para mostrarlos en el campo
/// que corresponde y no todos juntos arriba.
class ErrorApi implements Exception {
  final String mensaje;
  final bool sesionVencida;
  final Map<String, String> errores;

  const ErrorApi(this.mensaje, {this.sesionVencida = false, this.errores = const {}});

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
    final cuerpoCodificado = cuerpo == null ? null : jsonEncode(cuerpo);
    final pedido = switch (metodo) {
      'POST' => http.post(uri, headers: cabeceras, body: cuerpoCodificado),
      'PUT' => http.put(uri, headers: cabeceras, body: cuerpoCodificado),
      'PATCH' => http.patch(uri, headers: cabeceras, body: cuerpoCodificado),
      'DELETE' => http.delete(uri, headers: cabeceras),
      _ => http.get(uri, headers: cabeceras),
    };
    respuesta = await pedido.timeout(_espera);
  } catch (_) {
    // Servidor apagado, sin red, se agotó la espera o, en el navegador, un
    // bloqueo por CORS: para el visitante son todos el mismo problema.
    throw const ErrorApi('No se pudo conectar con el museo. Revisá tu conexión.');
  }

  // Un 401 significa cosas distintas según si el pedido llevaba token: con
  // token, que venció; sin token, que las credenciales no son correctas, y
  // ahí el mensaje de la API es el que hay que mostrar.
  if (respuesta.statusCode == 401 && token != null) {
    throw const ErrorApi('Tu sesión venció. Ingresá de nuevo.', sesionVencida: true);
  }
  if (respuesta.statusCode == 404 && mensaje404 != null) throw ErrorApi(mensaje404);
  // Un 201 es un alta correcta, igual de buena que un 200. Un 204 es un
  // borrado correcto y viene sin cuerpo, así que no hay nada que leer.
  if (respuesta.statusCode == 204) return const {};
  if (respuesta.statusCode != 200 && respuesta.statusCode != 201) {
    // Cuando la API rechaza el pedido (credenciales equivocadas, cuenta
    // desactivada) su mensaje explica el motivo y es mejor que uno genérico.
    // Cuando falla ella misma, no: "Error interno del servidor" no le dice
    // nada a quien está en una sala del museo.
    final suyo = respuesta.statusCode < 500 ? _mensajeDeError(respuesta) : null;
    throw ErrorApi(
      suyo ?? 'El museo no está respondiendo. Probá de nuevo en un rato.',
      errores: respuesta.statusCode < 500 ? _erroresPorCampo(respuesta) : const {},
    );
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

/// Los rechazos por campo, si la respuesta trae el objeto `errores`.
Map<String, String> _erroresPorCampo(http.Response respuesta) {
  try {
    final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final errores = cuerpo is Map ? cuerpo['errores'] : null;
    if (errores is! Map) return const {};
    return {
      for (final entrada in errores.entries)
        if (entrada.value is String) entrada.key.toString(): entrada.value as String,
    };
  } catch (_) {
    return const {};
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

// --- Administración de misiones -------------------------------------------
// Son las mismas rutas que usa el panel web, así que exigen token de
// administrador. La API rechaza igual aunque la app se equivoque.

/// GET /misiones — todas las misiones no archivadas, para administrarlas.
Future<List<MisionAdmin>> listarMisiones(String token) async {
  final cuerpo = await _pedirJson('/misiones', token: token);
  try {
    return (cuerpo['misiones'] as List)
        .map((json) => MisionAdmin.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// GET /misiones/:id — los datos completos, para editarla.
Future<MisionAdmin> obtenerMisionAdmin(String token, int id) async {
  final cuerpo = await _pedirJson(
    '/misiones/$id',
    token: token,
    mensaje404: 'Esa misión ya no existe.',
  );
  return _misionDesde(cuerpo);
}

/// POST /misiones — crea una misión. Nace siempre en borrador.
Future<MisionAdmin> crearMision(String token, Map<String, dynamic> datos) async {
  final cuerpo = await _pedirJson('/misiones', token: token, metodo: 'POST', cuerpo: datos);
  return _misionDesde(cuerpo);
}

/// PUT /misiones/:id — guarda los cambios.
///
/// Devuelve también si hubo cambios de verdad: la API no toca la fila cuando
/// se guarda lo mismo, y la pantalla lo avisa en vez de mentir que guardó.
Future<({MisionAdmin mision, bool modificada})> editarMision(
  String token,
  int id,
  Map<String, dynamic> datos,
) async {
  final cuerpo = await _pedirJson(
    '/misiones/$id',
    token: token,
    metodo: 'PUT',
    cuerpo: datos,
    mensaje404: 'Esa misión ya no existe.',
  );
  return (mision: _misionDesde(cuerpo), modificada: cuerpo['modificada'] == true);
}

/// PATCH /misiones/:id/activa — publica o despublica la misión.
///
/// Va en su propia ruta y no en el PUT para que guardar el formulario no
/// publique una misión sin querer.
///
/// Si se intenta publicar una sin desafíos la API responde 409 con su propio
/// mensaje, que ya explica qué falta: se muestra ese y no uno genérico.
Future<MisionAdmin> cambiarPublicacion(String token, int id, {required bool activa}) async {
  final cuerpo = await _pedirJson(
    '/misiones/$id/activa',
    token: token,
    metodo: 'PATCH',
    cuerpo: {'activa': activa},
    mensaje404: 'Esa misión ya no existe.',
  );
  return _misionDesde(cuerpo);
}

/// PATCH /misiones/:id/archivada — archiva la misión.
///
/// Es una baja lógica: deja de verse en la administración, pero sus desafíos y
/// el avance de los visitantes siguen en la base. Archivar también despublica,
/// lo hace la propia API.
Future<MisionAdmin> archivarMision(String token, int id) async {
  final cuerpo = await _pedirJson(
    '/misiones/$id/archivada',
    token: token,
    metodo: 'PATCH',
    cuerpo: {'archivada': true},
    mensaje404: 'Esa misión ya no existe.',
  );
  return _misionDesde(cuerpo);
}

MisionAdmin _misionDesde(Map<String, dynamic> cuerpo) {
  try {
    return MisionAdmin.desdeJson(cuerpo['mision'] as Map<String, dynamic>);
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

// --- Administración de desafíos -------------------------------------------

/// GET /misiones/:id/desafios — los desafíos de una misión, en orden.
///
/// La API devuelve también el nombre de la misión, así que la pantalla puede
/// titularse sola sin pedir la misión por separado.
Future<({String mision, List<Desafio> desafios})> listarDesafios(String token, int misionId) async {
  final cuerpo = await _pedirJson(
    '/misiones/$misionId/desafios',
    token: token,
    mensaje404: 'Esa misión ya no existe.',
  );
  try {
    return (
      mision: (cuerpo['mision'] as Map<String, dynamic>)['nombre'] as String,
      desafios: (cuerpo['desafios'] as List)
          .map((json) => Desafio.desdeJson(json as Map<String, dynamic>))
          .toList(),
    );
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// POST /misiones/:id/desafios — agrega un desafío al final de la misión.
///
/// El orden lo calcula la API: el desafío nuevo va último.
Future<Desafio> crearDesafio(String token, int misionId, Map<String, dynamic> datos) async {
  final cuerpo = await _pedirJson(
    '/misiones/$misionId/desafios',
    token: token,
    metodo: 'POST',
    cuerpo: datos,
    mensaje404: 'Esa misión ya no existe.',
  );
  return _desafioDesde(cuerpo);
}

/// PUT /desafios/:id — guarda los cambios de un desafío.
Future<Desafio> editarDesafio(String token, int id, Map<String, dynamic> datos) async {
  final cuerpo = await _pedirJson(
    '/desafios/$id',
    token: token,
    metodo: 'PUT',
    cuerpo: datos,
    mensaje404: 'Ese desafío ya no existe.',
  );
  return _desafioDesde(cuerpo);
}

Desafio _desafioDesde(Map<String, dynamic> cuerpo) {
  try {
    return Desafio.desdeJson(cuerpo['desafio'] as Map<String, dynamic>);
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// PUT /misiones/:id/desafios/orden — cambia el orden de los desafíos.
///
/// Se manda la lista completa de ids en el orden deseado y no "subí este": así
/// el servidor tiene una sola verdad, el orden que llega es el final. La API
/// devuelve los desafíos ya renumerados.
Future<List<Desafio>> reordenarDesafios(String token, int misionId, List<int> ids) async {
  final cuerpo = await _pedirJson(
    '/misiones/$misionId/desafios/orden',
    token: token,
    metodo: 'PUT',
    cuerpo: {'ids': ids},
    mensaje404: 'Esa misión ya no existe.',
  );
  try {
    return (cuerpo['desafios'] as List)
        .map((json) => Desafio.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// DELETE /desafios/:id — borra un desafío.
///
/// Devuelve si la misión quedó despublicada: quedarse sin desafíos la vuelve a
/// borrador sola, y eso hay que avisarlo porque no se pidió.
Future<bool> borrarDesafio(String token, int id) async {
  final cuerpo = await _pedirJson(
    '/desafios/$id',
    token: token,
    metodo: 'DELETE',
    mensaje404: 'Ese desafío ya no existe.',
  );
  return cuerpo['despublicada'] == true;
}

/// GET /objetos — las piezas del museo, para elegir la de un desafío.
Future<List<Objeto>> listarObjetos(String token) async {
  final cuerpo = await _pedirJson('/objetos', token: token);
  try {
    return (cuerpo['objetos'] as List)
        .map((json) => Objeto.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// GET /salas — las salas del museo, en el orden del recorrido.
///
/// Es sólo de lectura: las salas se cargan en la base y nunca se
/// administraron desde el panel.
Future<List<Sala>> listarSalas(String token) async {
  final cuerpo = await _pedirJson('/salas', token: token);
  try {
    return (cuerpo['salas'] as List)
        .map((json) => Sala.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// POST /objetos — carga una pieza. La API le genera el código sola.
Future<Objeto> crearObjeto(String token, Map<String, dynamic> datos) async {
  final cuerpo = await _pedirJson('/objetos', token: token, metodo: 'POST', cuerpo: datos);
  return _objetoDesde(cuerpo);
}

/// PUT /objetos/:id — guarda los cambios de una pieza.
///
/// El código no se toca acá: cambiarlo dejaría inservible la etiqueta que ya
/// está puesta junto a la pieza. Para eso está su propia ruta.
///
/// Devuelve también si hubo cambios de verdad, igual que al editar una misión.
Future<({Objeto objeto, bool modificado})> editarObjeto(
  String token,
  int id,
  Map<String, dynamic> datos,
) async {
  final cuerpo = await _pedirJson(
    '/objetos/$id',
    token: token,
    metodo: 'PUT',
    cuerpo: datos,
    mensaje404: 'Esa pieza ya no existe.',
  );
  return (objeto: _objetoDesde(cuerpo), modificado: cuerpo['modificado'] == true);
}

/// PATCH /objetos/:id/codigo — le genera un código nuevo a la pieza.
///
/// Va en su propia ruta y no en el formulario para que el código no se pueda
/// cambiar sin querer al guardar los datos: cambiarlo deja inservible la
/// etiqueta que ya está puesta junto a la pieza.
Future<Objeto> regenerarCodigo(String token, int id) async {
  final cuerpo = await _pedirJson(
    '/objetos/$id/codigo',
    token: token,
    metodo: 'PATCH',
    cuerpo: const {},
    mensaje404: 'Esa pieza ya no existe.',
  );
  return _objetoDesde(cuerpo);
}

/// PATCH /objetos/:id/estado — da de baja o reactiva una pieza.
///
/// Es una baja lógica: la pieza sigue en la base y los desafíos que la usan
/// siguen funcionando. Deja de ofrecerse para desafíos nuevos.
Future<Objeto> cambiarEstadoObjeto(String token, int id, {required bool activo}) async {
  final cuerpo = await _pedirJson(
    '/objetos/$id/estado',
    token: token,
    metodo: 'PATCH',
    cuerpo: {'activo': activo},
    mensaje404: 'Esa pieza ya no existe.',
  );
  return _objetoDesde(cuerpo);
}

/// DELETE /objetos/:id — borra una pieza del museo.
///
/// A diferencia de una misión, que se archiva, acá el borrado es real. La API
/// rechaza con 409 si algún desafío usa la pieza: para esos casos está la baja.
Future<void> borrarObjeto(String token, int id) async {
  await _pedirJson(
    '/objetos/$id',
    token: token,
    metodo: 'DELETE',
    mensaje404: 'Esa pieza ya no existe.',
  );
}

/// GET /objetos/:id/desafios — en qué desafíos se usa la pieza.
///
/// Es lo que explica por qué una pieza en uso no se puede borrar.
Future<List<UsoDeObjeto>> listarDesafiosDeObjeto(String token, int id) async {
  final cuerpo = await _pedirJson(
    '/objetos/$id/desafios',
    token: token,
    mensaje404: 'Esa pieza ya no existe.',
  );
  try {
    return (cuerpo['desafios'] as List)
        .map((json) => UsoDeObjeto.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

Objeto _objetoDesde(Map<String, dynamic> cuerpo) {
  try {
    return Objeto.desdeJson(cuerpo['objeto'] as Map<String, dynamic>);
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

/// GET /publico/misiones/:id/desafios — los desafíos a jugar, en orden (VIS04).
///
/// No trae las respuestas correctas ni cómo se comparan: eso se queda en el
/// servidor. Un 404 acá significa que el museo bajó la misión entre que se
/// abrió el detalle y se apretó "Comenzar recorrido".
Future<List<DesafioJugable>> obtenerDesafiosJugables(int misionId) async {
  final cuerpo = await _pedirJson(
    '/publico/misiones/$misionId/desafios',
    mensaje404: 'Esta misión ya no está disponible.',
  );
  try {
    return (cuerpo['desafios'] as List)
        .map((json) => DesafioJugable.desdeJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}

/// POST /publico/desafios/:id/escaneo — valida el código leído del QR contra
/// la pieza que el desafío espera (VIS05, SIS01).
///
/// Un código equivocado no es un error: la API contesta 200 con
/// `correcto: false` y la pantalla lo cuenta como un intento fallido. Lo que
/// sí es error es un 409, que significa que este desafío no se escanea.
Future<ResultadoEscaneo> escanearCodigo(int desafioId, String codigo) async {
  final cuerpo = await _pedirJson(
    '/publico/desafios/$desafioId/escaneo',
    metodo: 'POST',
    cuerpo: {'codigo': codigo},
    mensaje404: 'Este desafío ya no está disponible.',
  );
  try {
    return ResultadoEscaneo.desdeJson(cuerpo);
  } catch (_) {
    throw const ErrorApi('La respuesta del museo no se entendió.');
  }
}
