import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/desafio.dart';
import '../../modelos/objeto.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';

/// Las mismas reglas que aplica la API, en backend/src/validaciones/desafio.js.
/// Están repetidas acá para avisar al instante, sin esperar al servidor; la
/// API es la que manda y vuelve a revisar todo.
const puntosMaximos = 1000;
const minimoOpciones = 2;
const maximoOpciones = 6;
const largoMaximoOpcion = 200;
const largoMaximoRespuesta = 200;

/// Formulario de un desafío, compartido por el alta y la edición, para que
/// crear y editar no terminen con validaciones distintas.
class FormularioDesafio extends StatefulWidget {
  /// El desafío que se edita, o null si se está creando uno.
  final Desafio? desafio;

  /// Guarda y devuelve el aviso a mostrar. Si lanza un ErrorApi con errores
  /// por campo, el formulario los reparte en sus campos.
  final Future<String?> Function(Map<String, dynamic> datos) alGuardar;

  final String textoBoton;

  const FormularioDesafio({
    super.key,
    required this.desafio,
    required this.alGuardar,
    required this.textoBoton,
  });

  @override
  State<FormularioDesafio> createState() => _FormularioDesafioState();
}

class _FormularioDesafioState extends State<FormularioDesafio> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _enunciado;
  late final TextEditingController _puntos;
  late final TextEditingController _respuesta;

  TipoDesafio? _tipo;
  int? _objetoId;
  String _tolerancia = 'flexible';

  /// Las opciones de una pregunta de opción múltiple.
  ///
  /// La correcta se guarda como la posición y no como el texto: así, al
  /// corregir una opción ya marcada, la marca no se pierde. A la API se le
  /// manda el texto, que es lo que ella espera.
  late final List<TextEditingController> _opciones;
  int? _correcta;

  Future<List<Objeto>>? _objetos;

  bool _guardando = false;
  String _error = '';
  String _aviso = '';

  /// Errores de lo que no es un campo de texto: el tipo, el objeto y las
  /// opciones. Los de los campos de texto los muestra cada TextFormField.
  final Map<String, String> _erroresPropios = {};

  /// Errores que devolvió la API por campo, para mostrarlos donde van.
  Map<String, String> _erroresApi = {};

  @override
  void initState() {
    super.initState();
    final d = widget.desafio;
    _enunciado = TextEditingController(text: d?.enunciado ?? '');
    _puntos = TextEditingController(text: '${d?.puntos ?? 10}');
    _respuesta = TextEditingController(text: d?.respuestaCorrecta ?? '');
    _tipo = d?.tipo;
    _objetoId = d?.objetoId;
    _tolerancia = d?.tolerancia ?? 'flexible';

    // Una pregunta nueva arranca con las dos opciones mínimas, para que se vea
    // de entrada que hay que cargar al menos dos.
    final cargadas = d?.opciones ?? const <String>[];
    _opciones = [
      for (final texto in cargadas) TextEditingController(text: texto),
      for (var i = cargadas.length; i < minimoOpciones; i++) TextEditingController(),
    ];
    // Al abrir una pregunta ya cargada, la marca va donde estaba.
    final indice = cargadas.indexOf(d?.respuestaCorrecta ?? '');
    _correcta = indice >= 0 ? indice : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _objetos ??= _pedirObjetos();
  }

  Future<List<Objeto>> _pedirObjetos() {
    final pedido = listarObjetos(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  @override
  void dispose() {
    _enunciado.dispose();
    _puntos.dispose();
    _respuesta.dispose();
    for (final opcion in _opciones) {
      opcion.dispose();
    }
    super.dispose();
  }

  /// Al tocar algo se descartan los rechazos de la API: son de un intento
  /// anterior y seguirían apareciendo sobre un dato ya corregido.
  void _alEscribir() {
    if (_erroresApi.isNotEmpty) setState(() => _erroresApi = {});
  }

  void _elegirTipo(TipoDesafio tipo) {
    setState(() {
      _tipo = tipo;
      _erroresPropios.remove('tipo');
      // Lo que ya no corresponde al tipo nuevo deja de estar en error: sus
      // campos ni siquiera se ven.
      _erroresPropios.remove('opciones');
      _erroresPropios.remove('objeto_id');
      _erroresApi = {};
      _error = '';
    });
  }

  void _agregarOpcion() {
    if (_opciones.length >= maximoOpciones) return;
    setState(() {
      _opciones.add(TextEditingController());
      _erroresPropios.remove('opciones');
    });
  }

  void _quitarOpcion(int indice) {
    if (_opciones.length <= minimoOpciones) return;
    setState(() {
      _opciones.removeAt(indice).dispose();
      // Si se quita la opción marcada, la marca queda sin dueño; si se quita
      // una anterior, la marca se corre junto con la lista.
      if (_correcta == indice) {
        _correcta = null;
      } else if (_correcta != null && _correcta! > indice) {
        _correcta = _correcta! - 1;
      }
      _erroresPropios.remove('opciones');
      _erroresPropios.remove('respuesta_correcta');
    });
  }

  /// Revisa lo que no es un campo de texto. Devuelve los errores encontrados.
  Map<String, String> _revisarPropios() {
    final errores = <String, String>{};

    if (_tipo == null) {
      errores['tipo'] = 'El tipo de desafío es obligatorio';
      // Sin tipo no tiene sentido revisar lo que depende de él.
      return errores;
    }

    if (_tipo!.necesitaObjeto && _objetoId == null) {
      errores['objeto_id'] = 'Para este tipo hay que elegir el objeto';
    }

    if (_tipo == TipoDesafio.preguntaOpcionMultiple) {
      // Las vacías se descartan, igual que hace la API: una fila en blanco es
      // una opción que el administrador dejó sin escribir, no una opción vacía.
      final cargadas = _opciones.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (cargadas.length < minimoOpciones || cargadas.length > maximoOpciones) {
        errores['opciones'] = 'Cargá entre $minimoOpciones y $maximoOpciones opciones';
      } else if (cargadas.any((o) => o.runes.length > largoMaximoOpcion)) {
        errores['opciones'] = 'Cada opción puede tener hasta $largoMaximoOpcion caracteres';
      } else if (cargadas.map((o) => o.toLowerCase()).toSet().length != cargadas.length) {
        // Dos opciones que el visitante lee como la misma harían la pregunta
        // imposible de responder.
        errores['opciones'] = 'No puede haber opciones repetidas';
      }

      final marcada = _textoCorrecto();
      if (marcada == null || marcada.isEmpty) {
        errores['respuesta_correcta'] = 'Marcá cuál es la opción correcta';
      }
    }

    return errores;
  }

  /// El texto de la opción marcada como correcta, si hay una y no está vacía.
  String? _textoCorrecto() {
    if (_correcta == null || _correcta! >= _opciones.length) return null;
    final texto = _opciones[_correcta!].text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _guardar() async {
    setState(() {
      _erroresApi = {};
      _erroresPropios.clear();
      _error = '';
      _aviso = '';
    });

    final okTexto = _formulario.currentState!.validate();
    final propios = _revisarPropios();
    if (!okTexto || propios.isNotEmpty) {
      setState(() {
        _erroresPropios.addAll(propios);
        _error = 'Revisá los campos marcados.';
      });
      return;
    }

    setState(() => _guardando = true);
    try {
      final aviso = await widget.alGuardar(_datos());
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
      debugPrint('Fallo al guardar el desafío: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Arma el cuerpo del pedido con lo común y sólo lo propio del tipo elegido.
  ///
  /// Mandar únicamente lo del tipo es a propósito: así, al cambiar el tipo de
  /// un desafío, no quedan guardados los datos del tipo anterior.
  Map<String, dynamic> _datos() {
    final datos = <String, dynamic>{
      'enunciado': _enunciado.text.trim(),
      'tipo': _tipo!.valorApi,
      'puntos': int.parse(_puntos.text.trim()),
      'objeto_id': _objetoId,
    };

    if (_tipo == TipoDesafio.preguntaOpcionMultiple) {
      datos['opciones'] =
          _opciones.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      datos['respuesta_correcta'] = _textoCorrecto();
    }
    if (_tipo == TipoDesafio.respuestaCorta) {
      datos['respuesta_correcta'] = _respuesta.text.trim();
      datos['tolerancia'] = _tolerancia;
    }

    return datos;
  }

  String? _validarEnunciado(String? valor) {
    if (_erroresApi['enunciado'] != null) return _erroresApi['enunciado'];
    return (valor ?? '').trim().isEmpty ? 'El enunciado es obligatorio' : null;
  }

  String? _validarPuntos(String? valor) {
    if (_erroresApi['puntos'] != null) return _erroresApi['puntos'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Los puntos son obligatorios';
    // Se revisa que sean sólo dígitos y no con tryParse: "10e2" o "+5" son
    // números para Dart pero no lo que esperamos acá.
    if (!RegExp(r'^\d+$').hasMatch(texto) || int.parse(texto) > puntosMaximos) {
      return 'Los puntos tienen que ser un número entero entre 0 y $puntosMaximos';
    }
    return null;
  }

  String? _validarRespuesta(String? valor) {
    if (_erroresApi['respuesta_correcta'] != null) return _erroresApi['respuesta_correcta'];
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'La respuesta correcta es obligatoria';
    if (texto.runes.length > largoMaximoRespuesta) {
      return 'La respuesta no puede superar los $largoMaximoRespuesta caracteres';
    }
    return null;
  }

  /// El error de un campo que no es de texto: el propio o el que devolvió la
  /// API, que pueden ser el mismo campo visto desde los dos lados.
  String? _errorDe(String campo) => _erroresPropios[campo] ?? _erroresApi[campo];

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

          const EtiquetaCampo('Enunciado', obligatorio: true),
          TextFormField(
            // La clave hace que Flutter reconozca este campo aunque cambie de
            // posición en la columna. Sin ella, cuando aparece o desaparece un
            // mensaje de error, los campos se corren, se rearman de cero y
            // pierden el error que la validación acababa de marcarles.
            key: const ValueKey('enunciado'),
            controller: _enunciado,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Lo que lee el visitante'),
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => _alEscribir(),
            validator: _validarEnunciado,
          ),
          const SizedBox(height: 22),

          const EtiquetaCampo('Tipo de desafío', obligatorio: true),
          Text(
            'Cada tipo pide sus propios datos, que aparecen abajo.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 10),
          for (final tipo in TipoDesafio.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FilaTipo(
                tipo: tipo,
                elegido: _tipo == tipo,
                alTocar: () => _elegirTipo(tipo),
              ),
            ),
          if (_errorDe('tipo') != null) _MensajeError(_errorDe('tipo')!),
          const SizedBox(height: 14),

          const EtiquetaCampo('Puntos', obligatorio: true),
          TextFormField(
            key: const ValueKey('puntos'),
            controller: _puntos,
            style: estiloCampo,
            decoration: decoracionCampo(pista: 'Entre 0 y $puntosMaximos'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _alEscribir(),
            validator: _validarPuntos,
          ),
          const SizedBox(height: 4),
          Text(
            'Lo que suma el visitante al resolverlo. 0 para uno que no puntúa.',
            style: AppText.sans(size: 12.5),
          ),
          const SizedBox(height: 22),

          // Lo propio de cada tipo. Sin tipo elegido no se muestra nada: no se
          // sabría qué pedir.
          if (_tipo == TipoDesafio.preguntaOpcionMultiple) _opcionesMultiples(),
          if (_tipo == TipoDesafio.respuestaCorta) _respuestaCorta(),
          if (_tipo != null && _tipo!.necesitaObjeto) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Text(
                'Este tipo no lleva respuesta escrita: se resuelve encontrando la '
                'pieza y escaneando su código.',
                style: AppText.sans(size: 13),
              ),
            ),
            const SizedBox(height: 22),
          ],

          _selectorDeObjeto(),

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
    // de widget, Flutter dejaría de emparejar los hijos de la columna desde
    // arriba y rearmaría los campos que siguen.
    return Padding(
      padding: EdgeInsets.only(bottom: texto.isEmpty ? 0 : 18),
      child: texto.isEmpty ? const SizedBox.shrink() : Aviso(texto, esError: esError),
    );
  }

  Widget _opcionesMultiples() {
    final error = _errorDe('opciones');
    final errorCorrecta = _errorDe('respuesta_correcta');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaCampo('Opciones', obligatorio: true),
        Text(
          'Entre $minimoOpciones y $maximoOpciones. Tocá el círculo para marcar la correcta.',
          style: AppText.sans(size: 12.5),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _opciones.length; i++)
          Padding(
            // La clave es el controlador de esa opción, no su posición: al
            // quitar una del medio, las de abajo se corren y así cada fila
            // sigue siendo la misma para Flutter.
            key: ObjectKey(_opciones[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // El círculo marca la correcta. Va pegado a su opción para que
                // no haya dudas de cuál se está marcando.
                IconButton(
                  onPressed: () => setState(() {
                    _correcta = i;
                    _erroresPropios.remove('respuesta_correcta');
                    _erroresApi.remove('respuesta_correcta');
                  }),
                  icon: Icon(
                    _correcta == i ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _correcta == i ? AppColors.facil : AppColors.textoInactivo,
                  ),
                  tooltip: 'La opción ${i + 1} es la correcta',
                ),
                Expanded(
                  child: TextFormField(
                    controller: _opciones[i],
                    style: estiloCampo,
                    decoration: decoracionCampo(pista: 'Opción ${i + 1}'),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      _alEscribir();
                      if (_erroresPropios.isNotEmpty) {
                        setState(() {
                          _erroresPropios.remove('opciones');
                          _erroresPropios.remove('respuesta_correcta');
                        });
                      }
                    },
                  ),
                ),
                // Con el mínimo cargado no se puede quitar ninguna: la API
                // rechazaría la pregunta igual.
                IconButton(
                  onPressed: _opciones.length <= minimoOpciones ? null : () => _quitarOpcion(i),
                  icon: const Icon(Icons.close),
                  color: AppColors.textoSecundario,
                  disabledColor: AppColors.borde,
                  tooltip: 'Quitar la opción ${i + 1}',
                ),
              ],
            ),
          ),
        if (error != null) _MensajeError(error),
        if (errorCorrecta != null) _MensajeError(errorCorrecta),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _opciones.length >= maximoOpciones ? null : _agregarOpcion,
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            _opciones.length >= maximoOpciones
                ? 'Llegaste al máximo de $maximoOpciones'
                : 'Agregar opción',
            style: AppText.sans(
              size: 13.5,
              color: _opciones.length >= maximoOpciones
                  ? AppColors.textoInactivo
                  : AppColors.acento,
              peso: FontWeight.w700,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.acento,
            disabledForegroundColor: AppColors.textoInactivo,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _respuestaCorta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaCampo('Respuesta correcta', obligatorio: true),
        TextFormField(
          key: const ValueKey('respuesta'),
          controller: _respuesta,
          style: estiloCampo,
          decoration: decoracionCampo(),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _alEscribir(),
          validator: _validarRespuesta,
        ),
        const SizedBox(height: 18),

        const EtiquetaCampo('Comparación', obligatorio: true),
        Text(
          'Cómo se compara lo que escribe el visitante con la respuesta.',
          style: AppText.sans(size: 12.5),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            for (final opcion in const [
              ('flexible', 'Flexible'),
              ('exacta', 'Exacta'),
            ])
              ButtonSegment(
                value: opcion.$1,
                // El color va acá y no en el estilo del botón: AppText.sans
                // fija el suyo y pisaría el del botón, dejando la opción
                // elegida en gris sobre ocre, que casi no se lee.
                label: Text(
                  opcion.$2,
                  style: AppText.sans(
                    size: 13,
                    color: _tolerancia == opcion.$1
                        ? AppColors.fondo
                        : AppColors.textoSecundario,
                    peso: _tolerancia == opcion.$1 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
          selected: {_tolerancia},
          onSelectionChanged: (elegida) => setState(() => _tolerancia = elegida.first),
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (estados) => estados.contains(WidgetState.selected)
                  ? AppColors.acento
                  : AppColors.superficie,
            ),
            side: const WidgetStatePropertyAll(BorderSide(color: AppColors.borde)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tolerancia == 'exacta'
              ? 'Tiene que escribirse igual, con tildes y mayúsculas.'
              : 'No distingue tildes ni mayúsculas.',
          style: AppText.sans(size: 12.5, color: AppColors.textoInactivo),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _selectorDeObjeto() {
    final obligatorio = _tipo?.necesitaObjeto ?? false;
    final error = _errorDe('objeto_id');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaCampo(
          'Objeto del museo',
          obligatorio: obligatorio,
          opcional: !obligatorio,
        ),
        if (obligatorio)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Es la pieza que el visitante tiene que encontrar y escanear.',
              style: AppText.sans(size: 12.5),
            ),
          ),
        FutureBuilder<List<Objeto>>(
          future: _objetos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _CajaDeTexto(texto: 'Cargando objetos…');
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CajaDeTexto(texto: 'No se pudieron cargar los objetos.'),
                  TextButton(
                    onPressed: () => setState(() => _objetos = _pedirObjetos()),
                    child: Text(
                      'Reintentar',
                      style: AppText.sans(size: 13.5, color: AppColors.acento, peso: FontWeight.w700),
                    ),
                  ),
                ],
              );
            }

            final objetos = snapshot.data ?? const <Objeto>[];
            // Si el desafío apunta a un objeto que ya no está en la lista, se
            // agrega una entrada para él: sin esto el selector no sabría qué
            // mostrar y rompería la pantalla.
            final ids = objetos.map((o) => o.id).toSet();
            final faltante = _objetoId != null && !ids.contains(_objetoId);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: error != null ? AppColors.dificil : AppColors.borde),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _objetoId,
                  isExpanded: true,
                  dropdownColor: AppColors.superficie,
                  iconEnabledColor: AppColors.textoSecundario,
                  hint: Text(
                    obligatorio ? 'Elegí el objeto' : 'Sin objeto asociado',
                    style: AppText.sans(size: 14, color: AppColors.textoInactivo),
                  ),
                  items: [
                    // Sin objeto sólo es una opción válida en los tipos que no
                    // lo exigen.
                    if (!obligatorio)
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sin objeto asociado', style: estiloCampo),
                      ),
                    if (faltante)
                      DropdownMenuItem<int?>(
                        value: _objetoId,
                        child: Text('Objeto #$_objetoId (ya no está)', style: estiloCampo),
                      ),
                    for (final objeto in objetos)
                      DropdownMenuItem<int?>(
                        value: objeto.id,
                        child: Text(
                          objeto.sala == null
                              ? objeto.etiqueta
                              : '${objeto.etiqueta} · ${objeto.sala}',
                          style: estiloCampo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (elegido) => setState(() {
                    _objetoId = elegido;
                    _erroresPropios.remove('objeto_id');
                    _erroresApi.remove('objeto_id');
                  }),
                ),
              ),
            );
          },
        ),
        if (error != null) _MensajeError(error),
      ],
    );
  }
}

/// Una fila para elegir el tipo del desafío.
class _FilaTipo extends StatelessWidget {
  final TipoDesafio tipo;
  final bool elegido;
  final VoidCallback alTocar;

  const _FilaTipo({required this.tipo, required this.elegido, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: elegido ? AppColors.acento : AppColors.borde),
        ),
        child: Row(
          children: [
            Icon(
              elegido ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: elegido ? AppColors.acento : AppColors.textoInactivo,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tipo.etiqueta,
                style: AppText.sans(
                  size: 14,
                  color: elegido ? AppColors.textoPrimario : AppColors.textoSecundario,
                  peso: elegido ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje de error de un campo que no es un TextFormField, con el mismo
/// aspecto que usan ellos.
class _MensajeError extends StatelessWidget {
  final String texto;
  const _MensajeError(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(texto, style: AppText.sans(size: 12.5, color: AppColors.dificil)),
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
