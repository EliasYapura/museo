import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/objeto.dart';
import '../../modelos/sala.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/objeto.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const largoMaximoNombreObjeto = 200;

/// Formulario de una pieza del museo, compartido por el alta y la edición,
/// para que crear y editar no terminen con validaciones distintas.
class FormularioObjeto extends StatefulWidget {
  /// La pieza que se edita, o null si se está cargando una.
  final Objeto? objeto;

  /// Guarda y devuelve el aviso a mostrar. Si lanza un ErrorApi con errores
  /// por campo, el formulario los reparte en sus campos.
  final Future<String?> Function(Map<String, dynamic> datos) alGuardar;

  final String textoBoton;

  const FormularioObjeto({
    super.key,
    required this.objeto,
    required this.alGuardar,
    required this.textoBoton,
  });

  @override
  State<FormularioObjeto> createState() => _FormularioObjetoState();
}

class _FormularioObjetoState extends State<FormularioObjeto> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _datoClave;
  late final TextEditingController _descripcion;
  late final TextEditingController _imagen;

  int? _salaId;
  late TipoIdentificador _identificador;

  Future<List<Sala>>? _salas;

  bool _guardando = false;
  String _error = '';
  String _aviso = '';

  /// Errores de lo que no es un campo de texto: la sala. Los de los campos de
  /// texto los muestra cada TextFormField.
  final Map<String, String> _erroresPropios = {};

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  @override
  void initState() {
    super.initState();
    final o = widget.objeto;
    _nombre = TextEditingController(text: o?.nombre ?? '');
    _datoClave = TextEditingController(text: o?.datoClave ?? '');
    _descripcion = TextEditingController(text: o?.descripcion ?? '');
    _imagen = TextEditingController(text: o?.imagenUrl ?? '');
    _salaId = o?.salaId;
    _identificador = o?.tipoIdentificador ?? TipoIdentificador.qr;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _salas ??= _pedirSalas();
  }

  Future<List<Sala>> _pedirSalas() {
    final pedido = listarSalas(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _datoClave.dispose();
    _descripcion.dispose();
    _imagen.dispose();
    super.dispose();
  }

  /// Al tocar algo se descartan los rechazos de la API: son de un intento
  /// anterior y seguirían apareciendo sobre un dato ya corregido.
  void _alEscribir() {
    if (_erroresApi.isNotEmpty) setState(() => _erroresApi = {});
  }

  Future<void> _guardar() async {
    setState(() {
      _erroresApi = {};
      _erroresPropios.clear();
      _error = '';
      _aviso = '';
    });

    final okTexto = _formulario.currentState!.validate();
    final faltaSala = _salaId == null;
    if (!okTexto || faltaSala) {
      setState(() {
        if (faltaSala) _erroresPropios['sala_id'] = 'La sala es obligatoria';
        _error = 'Revisá los campos marcados.';
      });
      return;
    }

    setState(() => _guardando = true);
    try {
      final descripcion = _descripcion.text.trim();
      final imagen = _imagen.text.trim();
      final aviso = await widget.alGuardar({
        'nombre': _nombre.text.trim(),
        'sala_id': _salaId,
        'dato_clave': _datoClave.text.trim(),
        // Sin texto se manda null, no la cadena vacía: así "sin descripción"
        // se representa siempre igual en la base.
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'imagen_url': imagen.isEmpty ? null : imagen,
        'tipo_identificador': _identificador.valorApi,
      });
      if (mounted && aviso != null) setState(() => _aviso = aviso);
    } on ErrorApi catch (error) {
      if (!mounted) return;
      setState(() {
        // Copia y no la lista que vino: más abajo se le sacan entradas a
        // medida que se corrigen, y la que trae el error puede ser constante.
        _erroresApi = {...error.errores};
        _error = error.errores.isEmpty ? error.mensaje : 'Revisá los campos marcados.';
      });
      // Vuelve a validar para que los mensajes de la API aparezcan abajo de
      // cada campo.
      _formulario.currentState!.validate();
    } catch (error, pila) {
      debugPrint('Fallo al guardar el objeto: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _validarNombre(String? valor) {
    if (_erroresApi['nombre'] != null) return _erroresApi['nombre'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El nombre es obligatorio';
    // runes cuenta puntos de código, igual que PostgreSQL, y no unidades
    // UTF-16 como length: así un emoji vale uno y no dos.
    if (texto.runes.length > largoMaximoNombreObjeto) {
      return 'El nombre no puede superar los $largoMaximoNombreObjeto caracteres';
    }
    return null;
  }

  String? _validarDatoClave(String? valor) {
    if (_erroresApi['dato_clave'] != null) return _erroresApi['dato_clave'];
    return (valor ?? '').trim().isEmpty ? 'El dato clave es obligatorio' : null;
  }

  String? _validarDescripcion(String? valor) {
    // Es opcional: sólo puede fallar del lado de la API.
    return _erroresApi['descripcion'];
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
  /// Siempre un Padding, aunque no haya nada que decir: si cambiara de tipo de
  /// widget, Flutter dejaría de emparejar los hijos de la columna desde arriba
  /// y rearmaría los campos que siguen, que perderían sus errores.
  Widget _avisoSuperior() {
    final esError = _error.isNotEmpty;
    final texto = esError ? _error : _aviso;
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
            // La clave hace que Flutter reconozca este campo aunque cambie de
            // posición en la columna y no pierda el error que se le marcó.
            key: const ValueKey('nombre'),
            controller: _nombre,
            style: estiloCampo,
            decoration: decoracionCampo(),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _alEscribir(),
            validator: _validarNombre,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Sala', obligatorio: true),
          _selectorDeSala(),
          const SizedBox(height: 18),

          const EtiquetaCampo('Dato clave', obligatorio: true),
          Text(
            'Lo que ve el visitante al escanear la pieza. Es la base de las preguntas.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('dato_clave'),
            controller: _datoClave,
            style: estiloCampo,
            decoration: decoracionCampo(),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => _alEscribir(),
            validator: _validarDatoClave,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Descripción', opcional: true),
          Text(
            'Información ampliada: origen, época, historia.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('descripcion'),
            controller: _descripcion,
            style: estiloCampo,
            decoration: decoracionCampo(),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => _alEscribir(),
            validator: _validarDescripcion,
          ),
          const SizedBox(height: 18),

          const EtiquetaCampo('Identificador de la pieza', obligatorio: true),
          Text(
            'Cómo va a escanear el visitante este objeto durante el recorrido.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 10),
          _selectorDeIdentificador(),
          const SizedBox(height: 18),

          const EtiquetaCampo('Imagen', opcional: true),
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

  Widget _selectorDeSala() {
    final error = _erroresPropios['sala_id'] ?? _erroresApi['sala_id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<Sala>>(
          future: _salas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _CajaDeTexto(texto: 'Cargando salas…');
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CajaDeTexto(texto: 'No se pudieron cargar las salas.'),
                  TextButton(
                    onPressed: () => setState(() => _salas = _pedirSalas()),
                    child: Text(
                      'Reintentar',
                      style: AppText.sans(size: 13.5, color: AppColors.acento, peso: FontWeight.w700),
                    ),
                  ),
                ],
              );
            }

            final salas = snapshot.data ?? const <Sala>[];
            // Si la pieza apunta a una sala que ya no está en la lista, se
            // agrega una entrada para ella: sin esto el selector no sabría qué
            // mostrar y rompería la pantalla.
            final faltante = _salaId != null && !salas.any((s) => s.id == _salaId);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: error != null ? AppColors.dificil : AppColors.borde),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _salaId,
                  isExpanded: true,
                  dropdownColor: AppColors.superficie,
                  iconEnabledColor: AppColors.textoSecundario,
                  hint: Text(
                    'Elegí la sala',
                    style: AppText.sans(size: 14, color: AppColors.textoInactivo),
                  ),
                  items: [
                    if (faltante)
                      DropdownMenuItem<int>(
                        value: _salaId,
                        child: Text('Sala #$_salaId (ya no está)', style: estiloCampo),
                      ),
                    for (final sala in salas)
                      DropdownMenuItem<int>(
                        value: sala.id,
                        child: Text(
                          sala.nombre,
                          style: estiloCampo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (elegida) => setState(() {
                    _salaId = elegida;
                    _erroresPropios.remove('sala_id');
                    _erroresApi.remove('sala_id');
                  }),
                ),
              ),
            );
          },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(error, style: AppText.sans(size: 12.5, color: AppColors.dificil)),
          ),
      ],
    );
  }

  Widget _selectorDeIdentificador() {
    return SegmentedButton<TipoIdentificador>(
      segments: [
        for (final tipo in TipoIdentificador.values)
          ButtonSegment(
            value: tipo,
            // El color va acá y no en el estilo del botón: AppText.sans fija
            // el suyo y pisaría el del botón, dejando la opción elegida en
            // gris sobre ocre, que casi no se lee.
            label: Text(
              tipo == TipoIdentificador.qr ? 'Código QR' : 'Etiqueta NFC',
              style: AppText.sans(
                size: 13,
                color: _identificador == tipo ? AppColors.fondo : AppColors.textoSecundario,
                peso: _identificador == tipo ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
      selected: {_identificador},
      onSelectionChanged: (elegido) => setState(() => _identificador = elegido.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? AppColors.acento
              : AppColors.superficie,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.borde)),
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

/// Caja con el aspecto de un campo, para los estados en que todavía no hay uno.
class _CajaDeTexto extends StatelessWidget {
  final String texto;
  const _CajaDeTexto({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Text(texto, style: AppText.sans(size: 14, color: AppColors.textoInactivo)),
    );
  }
}
