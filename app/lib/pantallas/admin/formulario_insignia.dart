import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/insignia.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/insignia.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const largoMaximoNombreInsignia = 120;

/// Formulario de una insignia, compartido por el alta y la edición, para que
/// crear y editar no terminen con validaciones distintas.
///
/// No incluye la condición de obtención ni si está activa: las dos se cambian
/// por su propia vía, para que guardar un cambio de nombre no altere sin
/// querer quién puede ganarla.
class FormularioInsignia extends StatefulWidget {
  /// La insignia que se edita, o null si se está creando una.
  final Insignia? insignia;

  /// Guarda y devuelve el aviso a mostrar. Si lanza un ErrorApi con errores
  /// por campo, el formulario los reparte en sus campos.
  final Future<String?> Function(Map<String, dynamic> datos) alGuardar;

  final String textoBoton;

  const FormularioInsignia({
    super.key,
    required this.insignia,
    required this.alGuardar,
    required this.textoBoton,
  });

  @override
  State<FormularioInsignia> createState() => _FormularioInsigniaState();
}

class _FormularioInsigniaState extends State<FormularioInsignia> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _icono;

  bool _guardando = false;
  String _error = '';
  String _aviso = '';

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  @override
  void initState() {
    super.initState();
    final i = widget.insignia;
    _nombre = TextEditingController(text: i?.nombre ?? '');
    _descripcion = TextEditingController(text: i?.descripcion ?? '');
    _icono = TextEditingController(text: i?.iconoUrl ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _icono.dispose();
    super.dispose();
  }

  /// Al tocar algo se descartan los rechazos de la API: son de un intento
  /// anterior y seguirían apareciendo sobre un dato ya corregido.
  void _alEscribir() {
    if (_erroresApi.isEmpty && _error.isEmpty && _aviso.isEmpty) return;
    setState(() {
      _erroresApi = {};
      _error = '';
      _aviso = '';
    });
  }

  String? _validarNombre(String? valor) {
    if (_erroresApi['nombre'] != null) return _erroresApi['nombre'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El nombre es obligatorio';
    if (texto.runes.length > largoMaximoNombreInsignia) {
      return 'El nombre no puede superar los $largoMaximoNombreInsignia caracteres';
    }
    return null;
  }

  String? _validarDescripcion(String? valor) {
    if (_erroresApi['descripcion'] != null) return _erroresApi['descripcion'];
    if ((valor ?? '').trim().isEmpty) return 'La descripción es obligatoria';
    return null;
  }

  /// El ícono es opcional, pero si se escribe algo tiene que ser una dirección
  /// http o https: la API rechaza cualquier otra cosa.
  String? _validarIcono(String? valor) {
    if (_erroresApi['icono_url'] != null) return _erroresApi['icono_url'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final uri = Uri.tryParse(texto);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Tiene que ser una dirección que empiece con http o https';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = '';
      _aviso = '';
    });

    try {
      final aviso = await widget.alGuardar({
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'icono_url': _icono.text.trim(),
      });
      if (!mounted) return;
      setState(() => _aviso = aviso ?? '');
    } on ErrorApi catch (error) {
      if (!mounted) return;
      setState(() {
        _erroresApi = error.errores;
        // Si la API explicó qué campo está mal, el mensaje va en el campo y
        // arriba no hace falta repetirlo.
        _error = error.errores.isEmpty ? error.mensaje : '';
      });
      // Vuelve a validar para que los campos muestren lo que rechazó la API.
      _formulario.currentState?.validate();
    } catch (error, pila) {
      debugPrint('Fallo al guardar la insignia: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar la insignia.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formulario,
      // Una vez enviado, los mensajes se actualizan a medida que se corrige,
      // sin esperar a tocar el botón otra vez.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaCampo('Nombre', obligatorio: true),
          TextFormField(
            controller: _nombre,
            enabled: !_guardando,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Paleontólogo junior'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _alEscribir(),
            validator: _validarNombre,
          ),
          const SizedBox(height: 4),
          Text('No puede repetirse con otra insignia.', style: AppText.sans(size: 12.5)),
          const SizedBox(height: 18),

          const EtiquetaCampo('Descripción', obligatorio: true),
          TextFormField(
            controller: _descripcion,
            enabled: !_guardando,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Completaste las misiones de paleontología.'),
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _alEscribir(),
            validator: _validarDescripcion,
          ),
          const SizedBox(height: 4),
          Text(
            'Es lo que lee el visitante cuando la gana: tiene que decirle por qué.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Ícono', opcional: true),
          TextFormField(
            controller: _icono,
            enabled: !_guardando,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'https://…'),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => _alEscribir(),
            validator: _validarIcono,
          ),
          const SizedBox(height: 4),
          Text(
            'La dirección de una imagen. Sin ícono se muestra uno genérico.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 24),

          if (_error.isNotEmpty) ...[
            Aviso(_error),
            const SizedBox(height: 14),
          ],
          if (_aviso.isNotEmpty) ...[
            Aviso(_aviso, esError: false),
            const SizedBox(height: 14),
          ],

          BotonPrincipal(
            texto: widget.textoBoton,
            textoOcupado: 'Guardando…',
            ocupado: _guardando,
            alTocar: _guardar,
          ),
        ],
      ),
    );
  }
}
