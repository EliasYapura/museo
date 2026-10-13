import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../sesion/sesion.dart';

/// Inicio de sesión del administrador.
///
/// El visitante no inicia sesión: recorre el museo sin cuenta. Esta pantalla
/// es la puerta a la parte de administración.
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formulario = GlobalKey<FormState>();

  bool _enviando = false;
  bool _verPassword = false;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _error = '';
      _enviando = true;
    });
    try {
      await ProveedorSesion.de(context).iniciarSesion(_email.text.trim(), _password.text);
      // La pantalla de perfil ya muestra la sesión iniciada, así que alcanza
      // con volver atrás.
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ErrorApi ? error.mensaje : 'No se pudo iniciar sesión.';
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
            Text('Ingresar', style: AppText.serif(size: 26)),
            const SizedBox(height: 10),
            Text(
              'El acceso es para el equipo del museo. Para recorrer las misiones '
              'no hace falta ninguna cuenta.',
              style: AppText.sans(size: 14),
            ),
            const SizedBox(height: 24),

            if (_error.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dificil),
                ),
                child: Text(
                  _error,
                  style: AppText.sans(size: 13.5, color: AppColors.textoPrimario),
                ),
              ),
              const SizedBox(height: 18),
            ],

            Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Etiqueta('Email'),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: AppText.sans(size: 15, color: AppColors.textoPrimario),
                    decoration: _decoracion(),
                    validator: (valor) =>
                        (valor ?? '').trim().isEmpty ? 'Escribí tu email' : null,
                  ),
                  const SizedBox(height: 18),
                  const _Etiqueta('Contraseña'),
                  TextFormField(
                    controller: _password,
                    obscureText: !_verPassword,
                    style: AppText.sans(size: 15, color: AppColors.textoPrimario),
                    decoration: _decoracion().copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _verPassword = !_verPassword),
                        icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                        color: AppColors.textoSecundario,
                        tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
                      ),
                    ),
                    validator: (valor) =>
                        (valor ?? '').isEmpty ? 'Escribí tu contraseña' : null,
                    onFieldSubmitted: (_) => _entrar(),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _enviando ? null : _entrar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.acento,
                        disabledBackgroundColor: AppColors.superficie,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _enviando ? 'Ingresando…' : 'Ingresar',
                        style: AppText.sans(
                          size: 15,
                          color: _enviando ? AppColors.textoInactivo : AppColors.fondo,
                          peso: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion() => InputDecoration(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.acento),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dificil),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dificil),
        ),
        errorStyle: AppText.sans(size: 12.5, color: AppColors.dificil),
      );
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto, style: AppText.sans(size: 13.5, peso: FontWeight.w700)),
      );
}
