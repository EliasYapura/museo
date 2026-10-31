import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../sesion/sesion.dart';
import '../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/routes/auth.js. Están
/// repetidas acá para avisar al instante, sin esperar al servidor; la API es
/// la que manda y vuelve a revisar todo.
const largoMinimoContrasena = 8;
const largoMaximoNombre = 120;
const largoMaximoEmail = 255;

/// bcrypt ignora en silencio lo que pase de 72 bytes, así que dos contraseñas
/// larguísimas que sólo difieren al final serían intercambiables. El límite se
/// cuenta en bytes y no en caracteres porque una tilde ocupa dos.
const bytesMaximosContrasena = 72;

final _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Crear una cuenta de visitante.
///
/// La cuenta es opcional: para recorrer el museo no hace falta. Lo que suma es
/// que el avance quede guardado y se pueda retomar una misión empezada (SIS03).
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = ControladorContrasena();

  bool _enviando = false;
  String _error = '';

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formulario.currentState!.validate()) return;

    // Se toma antes del await: después de uno, usar el context ya no es
    // seguro, porque la pantalla pudo haberse ido.
    final sesion = ProveedorSesion.de(context);
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _error = '';
      _enviando = true;
    });
    try {
      await crearCuentaVisitante(_nombre.text.trim(), email, password);
      // Entra sola: pedirle que escriba de nuevo lo que acaba de escribir
      // sería hacerle hacer dos veces el mismo trámite.
      await sesion.iniciarSesion(email, password);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ErrorApi ? error.mensaje : 'No se pudo crear la cuenta.';
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _validarNombre(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribí tu nombre';
    if (texto.runes.length > largoMaximoNombre) {
      return 'El nombre no puede superar los $largoMaximoNombre caracteres';
    }
    return null;
  }

  String? _validarEmail(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribí tu email';
    if (!_emailRegExp.hasMatch(texto)) return 'Ese email no parece válido';
    if (texto.length > largoMaximoEmail) return 'Ese email es demasiado largo';
    return null;
  }

  String? _validarContrasena(String? valor) {
    final texto = valor ?? '';
    if (texto.length < largoMinimoContrasena) {
      return 'La contraseña tiene que tener al menos $largoMinimoContrasena caracteres';
    }
    if (utf8.encode(texto).length > bytesMaximosContrasena) {
      return 'Esa contraseña es demasiado larga';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.textoPrimario,
                  tooltip: 'Volver',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Crear una cuenta', style: AppText.serif(size: 26)),
            const SizedBox(height: 10),
            Text(
              'Con una cuenta, el museo guarda tu avance: si dejás una misión '
              'por la mitad, podés retomarla donde ibas.',
              style: AppText.sans(size: 14),
            ),
            const SizedBox(height: 24),

            if (_error.isNotEmpty) ...[
              Aviso(_error),
              const SizedBox(height: 18),
            ],

            Form(
              key: _formulario,
              // Una vez enviado, los mensajes se actualizan a medida que se
              // corrige, sin esperar a tocar el botón otra vez.
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetaCampo('Nombre', obligatorio: true),
                  TextFormField(
                    controller: _nombre,
                    enabled: !_enviando,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: estiloCampo,
                    decoration: decoracionCampo(pista: 'Cómo querés que te llamemos'),
                    validator: _validarNombre,
                  ),
                  const SizedBox(height: 18),

                  const EtiquetaCampo('Email', obligatorio: true),
                  TextFormField(
                    controller: _email,
                    enabled: !_enviando,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: estiloCampo,
                    decoration: decoracionCampo(),
                    validator: _validarEmail,
                  ),
                  const SizedBox(height: 18),

                  const EtiquetaCampo('Contraseña', obligatorio: true),
                  TextFormField(
                    controller: _password,
                    enabled: !_enviando,
                    // Sin obscureText a propósito: el enmascarado lo hace el
                    // controlador, que no deja ver ni el último carácter.
                    // El resto apaga lo que el teclado hace con un campo
                    // común: sugerencias, corrección y aprender lo tipeado.
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    // Mientras está oculta no se puede seleccionar ni copiar,
                    // igual que en un campo con obscureText.
                    enableInteractiveSelection: !_password.oculto,
                    style: estiloCampo,
                    decoration: decoracionCampo(
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _password.oculto = !_password.oculto),
                        icon: Icon(
                          _password.oculto ? Icons.visibility : Icons.visibility_off,
                        ),
                        color: AppColors.textoSecundario,
                        tooltip: _password.oculto ? 'Mostrar' : 'Ocultar',
                      ),
                    ),
                    validator: _validarContrasena,
                    onFieldSubmitted: (_) => _crear(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Al menos $largoMinimoContrasena caracteres.',
                    style: AppText.sans(size: 12.5),
                  ),
                  const SizedBox(height: 26),

                  BotonPrincipal(
                    texto: 'Crear la cuenta',
                    textoOcupado: 'Creando…',
                    ocupado: _enviando,
                    alTocar: _crear,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
