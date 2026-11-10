import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/mision.dart';
import '../../modelos/mision_admin.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/mision.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const duracionMinima = 1;
const duracionMaxima = 240;
const largoMaximoNombre = 200;

/// Formulario de los datos de una misión, compartido por el alta y la edición,
/// para que crear y editar no terminen con validaciones distintas.
class FormularioMision extends StatefulWidget {
  /// La misión que se edita, o null si se está creando una.
  final MisionAdmin? mision;

  /// Guarda y devuelve el aviso a mostrar. Si lanza un ErrorApi con errores
  /// por campo, el formulario los reparte en sus campos.
  final Future<String?> Function(Map<String, dynamic> datos) alGuardar;

  final String textoBoton;

  const FormularioMision({
    super.key,
    required this.mision,
    required this.alGuardar,
    required this.textoBoton,
  });

  @override
  State<FormularioMision> createState() => _FormularioMisionState();
}

class _FormularioMisionState extends State<FormularioMision> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _duracion;
  late final TextEditingController _imagen;

  bool _guardando = false;
  String _error = '';
  String _aviso = '';

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  @override
  void initState() {
    super.initState();
    final m = widget.mision;
    _nombre = TextEditingController(text: m?.nombre ?? '');
    _descripcion = TextEditingController(text: m?.descripcion ?? '');
    _duracion = TextEditingController(text: m == null ? '' : '${m.duracionMin}');
    _imagen = TextEditingController(text: m?.imagenUrl ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _duracion.dispose();
    _imagen.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // Los errores de la API quedaron de un intento anterior: al volver a
    // enviar se descartan, si no se mostrarían sobre datos ya corregidos.
    setState(() {
      _erroresApi = {};
      _error = '';
      _aviso = '';
    });
    if (!_formulario.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final imagen = _imagen.text.trim();
      final aviso = await widget.alGuardar({
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'duracion_estimada': int.parse(_duracion.text.trim()),
        // Sin imagen se manda null, no el texto vacío.
        'imagen_url': imagen.isEmpty ? null : imagen,
      });
      if (mounted && aviso != null) setState(() => _aviso = aviso);
    } on ErrorApi catch (error) {
      if (!mounted) return;
      setState(() {
        _erroresApi = error.errores;
        _error = error.errores.isEmpty ? error.mensaje : 'Revisá los campos marcados.';
      });
      // Vuelve a validar para que los mensajes de la API aparezcan abajo de
      // cada campo.
      _formulario.currentState!.validate();
    } catch (error, pila) {
      // Al administrador se le muestra algo legible, pero el detalle queda en
      // la consola: si no, un fallo inesperado no deja ningún rastro.
      debugPrint('Fallo al guardar la misión: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Al tocar un campo se descartan los rechazos de la API: son de un intento
  /// anterior y seguirían apareciendo sobre un dato ya corregido.
  void _alEscribir() {
    if (_erroresApi.isNotEmpty) setState(() => _erroresApi = {});
  }

  String? _validarNombre(String? valor) {
    if (_erroresApi['nombre'] != null) return _erroresApi['nombre'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El nombre es obligatorio';
    // runes cuenta puntos de código, igual que PostgreSQL, y no unidades
    // UTF-16 como length: así un emoji vale uno y no dos.
    if (texto.runes.length > largoMaximoNombre) {
      return 'El nombre no puede superar los $largoMaximoNombre caracteres';
    }
    return null;
  }

  String? _validarDescripcion(String? valor) {
    if (_erroresApi['descripcion'] != null) return _erroresApi['descripcion'];
    return (valor ?? '').trim().isEmpty ? 'La descripción es obligatoria' : null;
  }

  String? _validarDuracion(String? valor) {
    if (_erroresApi['duracion_estimada'] != null) return _erroresApi['duracion_estimada'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'La duración es obligatoria';
    final minutos = int.tryParse(texto);
    if (minutos == null) return 'La duración debe ser un número entero de minutos';
    if (minutos < duracionMinima || minutos > duracionMaxima) {
      return 'La duración debe estar entre $duracionMinima y $duracionMaxima minutos';
    }
    return null;
  }

  String? _validarImagen(String? valor) {
    if (_erroresApi['imagen_url'] != null) return _erroresApi['imagen_url'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final uri = Uri.tryParse(texto);
    if (uri == null || !uri.isAbsolute || !['http', 'https'].contains(uri.scheme)) {
      return 'La dirección tiene que empezar con http:// o https://';
    }
    return null;
  }

  /// El aviso de arriba de todo: el error general o la confirmación.
  ///
  /// Ocupa siempre un lugar en la columna, aunque esté vacío. Si apareciera y
  /// desapareciera, todos los campos de abajo se correrían una posición;
  /// Flutter empareja los hijos de una columna por posición, así que al no
  /// coincidir los rearma de cero y los campos pierden el error que la
  /// validación acababa de marcarles.
  Widget _avisoSuperior() {
    final esError = _error.isNotEmpty;
    final texto = esError ? _error : _aviso;
    // Siempre un Padding, aunque no haya nada que decir: si cambiara de tipo
    // de widget, Flutter dejaria de emparejar los hijos de la columna desde
    // arriba y rearmaria los campos que siguen.
    return Padding(
      padding: EdgeInsets.only(bottom: texto.isEmpty ? 0 : 18),
      child: texto.isEmpty ? const SizedBox.shrink() : Aviso(texto, esError: esError),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formulario,
      // Una vez que el formulario se envió, los mensajes se actualizan a
      // medida que se escribe: corregir un campo borra su error sin tener que
      // volver a mandar el formulario para enterarse.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avisoSuperior(),

          const EtiquetaCampo('Nombre', obligatorio: true),
          TextFormField(
            key: const ValueKey('nombre'),
            controller: _nombre,
            style: estiloCampo,
            decoration: decoracionCampo(),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _alEscribir(),
            validator: _validarNombre,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Descripción', obligatorio: true),
          TextFormField(
            key: const ValueKey('descripcion'),
            controller: _descripcion,
            style: estiloCampo,
            decoration: decoracionCampo(),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => _alEscribir(),
            validator: _validarDescripcion,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Duración estimada (minutos)', obligatorio: true),
          TextFormField(
            key: const ValueKey('duracion'),
            controller: _duracion,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Entre $duracionMinima y $duracionMaxima'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _alEscribir(),
            validator: _validarDuracion,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Dificultad'),
          // Ya no se elige: la calcula el servidor con la duracion, la cantidad
          // de desafios y el tipo de cada uno (ADM03). Se muestra igual, porque
          // el administrador tiene que poder ver que nivel le quedo a la mision
          // sin salir del formulario.
          _DificultadCalculada(dificultad: widget.mision?.dificultad),
          const SizedBox(height: 18),

          const EtiquetaCampo('Imagen de portada', opcional: true),
          TextFormField(
            key: const ValueKey('imagen'),
            controller: _imagen,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'https://…'),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: _validarImagen,
            onChanged: (_) {
              _alEscribir();
              setState(() {});
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Dirección de una imagen ya publicada en internet.',
            style: AppText.sans(size: 12.5),
          ),
          if (_imagen.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _VistaPrevia(url: _imagen.text.trim()),
          ],

          const SizedBox(height: 26),
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

/// Muestra la imagen cargada para poder ver si la dirección es la correcta
/// antes de guardar.
class _VistaPrevia extends StatelessWidget {
  final String url;
  const _VistaPrevia({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        // Sin etiqueta el lector de pantalla anuncia "imagen" y nada más. Acá
        // lo útil no es describir la foto —que la carga quien la está
        // mirando— sino decir de qué imagen se trata.
        semanticLabel: 'Vista previa de la portada de la misión',
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, hijo, progreso) => progreso == null
            ? hijo
            : Container(
                height: 160,
                color: AppColors.superficie,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppColors.acento),
              ),
        // Una dirección que no carga es lo más común al pegar un enlace, así
        // que se avisa en vez de dejar un hueco.
        errorBuilder: (context, error, pila) => Container(
          height: 160,
          color: AppColors.superficie,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Text(
            'No se pudo cargar la imagen desde esa dirección.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 13),
          ),
        ),
      ),
    );
  }
}

/// La dificultad que calculo el servidor (ADM03).
///
/// En una mision nueva todavia no hay ninguna: se calcula al guardar, cuando
/// el servidor ya conoce la duracion. Decirlo es mejor que mostrar un nivel
/// inventado que despues cambia solo.
class _DificultadCalculada extends StatelessWidget {
  final Dificultad? dificultad;

  const _DificultadCalculada({required this.dificultad});

  @override
  Widget build(BuildContext context) {
    final nivel = dificultad;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 17, color: AppColors.acento),
              const SizedBox(width: 9),
              Text(
                nivel == null ? 'Se calcula al guardar' : nivel.etiqueta,
                style: AppText.sans(
                  size: 14.5,
                  color: nivel == null ? AppColors.textoSecundario : AppColors.textoPrimario,
                  peso: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'La calcula el sistema con la duración, la cantidad de desafíos y el '
            'tipo de cada uno. Cambia sola cuando cambia la misión.',
            style: AppText.sans(size: 12.5),
          ),
        ],
      ),
    );
  }
}
