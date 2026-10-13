import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/cliente.dart';

/// Quién está usando la app.
///
/// Un visitante no inicia sesión: la app se usa sin cuenta. Iniciar sesión es
/// lo que distingue al administrador, que además de recorrer puede cargar
/// contenido.
class Usuario {
  final int id;
  final String nombre;
  final String email;
  final String rol;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  bool get esAdministrador => rol == 'administrador';

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        email: json['email'] as String,
        rol: json['rol'] as String,
      );
}

/// Guarda la sesión y avisa a las pantallas cuando cambia.
///
/// El token se guarda cifrado con flutter_secure_storage, que en Android usa
/// el almacén de claves del sistema. Es una credencial: con ella, durante las
/// ocho horas que dura, se puede cargar y borrar contenido del museo.
class ControlSesion extends ChangeNotifier {
  static const _claveToken = 'token';

  final FlutterSecureStorage _almacen;

  ControlSesion({FlutterSecureStorage? almacen})
      : _almacen = almacen ?? const FlutterSecureStorage();

  String? _token;
  Usuario? _usuario;

  /// Mientras se lee el token guardado no se sabe todavía si hay sesión, y la
  /// pantalla de perfil no debería parpadear entre un estado y el otro.
  bool _cargando = true;

  String? get token => _token;
  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get haySesion => _token != null && _usuario != null;
  bool get esAdministrador => _usuario?.esAdministrador ?? false;

  /// Recupera la sesión guardada al abrir la app.
  ///
  /// El token puede haber vencido mientras la app estaba cerrada, así que no
  /// alcanza con que exista: se lo prueba contra la API antes de darlo por
  /// bueno. Si no sirve, se descarta en silencio y la app queda como
  /// visitante, que es lo que corresponde.
  Future<void> recuperar() async {
    try {
      final guardado = await _almacen.read(key: _claveToken);
      if (guardado != null) {
        _usuario = await obtenerPerfil(guardado);
        _token = guardado;
      }
    } catch (_) {
      await _borrarToken();
      _token = null;
      _usuario = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Inicia sesión. Propaga el ErrorApi para que el formulario lo muestre.
  Future<void> iniciarSesion(String email, String password) async {
    final (token, usuario) = await autenticar(email, password);
    _token = token;
    _usuario = usuario;
    try {
      await _almacen.write(key: _claveToken, value: token);
    } catch (_) {
      // Si el almacén falla, la sesión igual vale para este rato; lo único
      // que se pierde es no tener que volver a entrar la próxima vez.
    }
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    _token = null;
    _usuario = null;
    await _borrarToken();
    notifyListeners();
  }

  Future<void> _borrarToken() async {
    try {
      await _almacen.delete(key: _claveToken);
    } catch (_) {
      // Nada que hacer: si no se pudo borrar, igual la sesión ya no se usa.
    }
  }
}

/// Deja la sesión disponible para toda la app sin pasarla pantalla por
/// pantalla. Se usa con ControlSesion.de(context).
class ProveedorSesion extends InheritedNotifier<ControlSesion> {
  const ProveedorSesion({
    super.key,
    required ControlSesion control,
    required super.child,
  }) : super(notifier: control);

  static ControlSesion de(BuildContext context) {
    final proveedor = context.dependOnInheritedWidgetOfExactType<ProveedorSesion>();
    assert(proveedor != null, 'Falta ProveedorSesion arriba en el árbol');
    return proveedor!.notifier!;
  }
}
