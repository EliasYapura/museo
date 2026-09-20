import { useEffect, useState } from 'react'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'
import { TIPOS_DESAFIO } from '../tiposDesafio.js'
import Campo from './Campo.jsx'

// Formulario de un desafio, compartido por el alta y la edicion (ADM08), con
// los campos propios de cada tipo (ADM09). La respuesta correcta es de ADM12.
//
// Props:
// - valoresIniciales: { enunciado, tipo, objeto_id, opciones, tolerancia }.
//   Todos como los maneja el formulario: texto, salvo opciones, que es una
//   lista de textos.
// - alGuardar(cuerpo): envia los datos a la API.
// - textoBoton / textoEnviando.
// - alCancelar: si viene, muestra un boton Cancelar (se usa al editar).

const ORDEN_CAMPOS = ['enunciado', 'tipo', 'objeto_id', 'opciones', 'respuesta_correcta', 'tolerancia']
const AVISO_ERRORES = 'Revisá los campos marcados.'

// Las mismas reglas que la API, en backend/src/validaciones/desafio.js.
const TIPOS_CON_OBJETO = ['escaneo_objeto', 'busqueda_guiada']
const MINIMO_OPCIONES = 2
const MAXIMO_OPCIONES = 6

export default function FormularioDesafio({
  valoresIniciales,
  alGuardar,
  textoBoton,
  textoEnviando,
  alCancelar,
}) {
  const { token, cerrarSesion } = useSesion()

  const [objetos, setObjetos] = useState(null)
  const [campos, setCampos] = useState(valoresIniciales)
  const [errores, setErrores] = useState({})
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  useEffect(() => {
    let vigente = true
    pedir('/objetos', { token })
      .then(({ objetos }) => vigente && setObjetos(objetos))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(`No se pudieron cargar los objetos: ${err.message}`)
      })
    return () => {
      vigente = false
    }
  }, [token, cerrarSesion])

  function cambiar(evento) {
    const { name, value } = evento.target
    setCampos({ ...campos, [name]: value })
    if (errores[name]) {
      const { [name]: _quitado, ...resto } = errores
      setErrores(resto)
      if (Object.keys(resto).length === 0 && error === AVISO_ERRORES) setError('')
    }
  }

  // Opciones de una pregunta de opcion multiple: se editan como una lista.
  // La respuesta correcta se guarda como el texto de la opcion elegida, asi
  // que al corregir esa opcion hay que actualizarla para que la marca no se
  // pierda (ADM12).
  function cambiarOpcion(indice, valor) {
    const opciones = campos.opciones.map((opcion, i) => (i === indice ? valor : opcion))
    const eraLaCorrecta =
      campos.respuesta_correcta !== '' && campos.respuesta_correcta === campos.opciones[indice]
    setCampos({
      ...campos,
      opciones,
      respuesta_correcta: eraLaCorrecta ? valor : campos.respuesta_correcta,
    })
    const { opciones: _sinOpciones, respuesta_correcta: _sinRespuesta, ...resto } = errores
    setErrores(resto)
  }

  function agregarOpcion() {
    setCampos({ ...campos, opciones: [...campos.opciones, ''] })
  }

  function quitarOpcion(indice) {
    const opciones = campos.opciones.filter((_, i) => i !== indice)
    // Si se quita la opcion marcada como correcta, la marca queda sin dueño.
    const seguiaMarcada = opciones.includes(campos.respuesta_correcta)
    setCampos({
      ...campos,
      opciones,
      respuesta_correcta: seguiaMarcada ? campos.respuesta_correcta : '',
    })
  }

  function marcarCorrecta(opcion) {
    setCampos({ ...campos, respuesta_correcta: opcion })
    const { respuesta_correcta: _quitado, ...resto } = errores
    setErrores(resto)
  }

  async function enviar(evento) {
    evento.preventDefault()
    setError('')

    // Las mismas reglas que la API, que es la que manda.
    const encontrados = {}
    const enunciado = campos.enunciado.trim()
    if (enunciado === '') encontrados.enunciado = 'El enunciado es obligatorio'
    if (campos.tipo === '') encontrados.tipo = 'El tipo de desafío es obligatorio'
    if (TIPOS_CON_OBJETO.includes(campos.tipo) && campos.objeto_id === '') {
      encontrados.objeto_id = 'Para este tipo hay que elegir el objeto'
    }

    // Solo se manda lo que corresponde al tipo elegido: asi, al cambiar de
    // tipo, no se guardan los datos del anterior.
    const propiosDelTipo = {}
    if (campos.tipo === 'pregunta_opcion_multiple') {
      const opciones = campos.opciones.map((opcion) => opcion.trim()).filter((opcion) => opcion !== '')
      const distintas = new Set(opciones.map((opcion) => opcion.toLowerCase()))
      if (opciones.length < MINIMO_OPCIONES || opciones.length > MAXIMO_OPCIONES) {
        encontrados.opciones = `Cargá entre ${MINIMO_OPCIONES} y ${MAXIMO_OPCIONES} opciones`
      } else if (distintas.size !== opciones.length) {
        encontrados.opciones = 'No puede haber opciones repetidas'
      }

      const correcta = campos.respuesta_correcta.trim()
      if (correcta === '') encontrados.respuesta_correcta = 'Marcá cuál es la opción correcta'
      else if (!opciones.includes(correcta)) {
        encontrados.respuesta_correcta = 'La respuesta correcta tiene que ser una de las opciones'
      }
      propiosDelTipo.opciones = opciones
      propiosDelTipo.respuesta_correcta = correcta
    }
    if (campos.tipo === 'respuesta_corta') {
      const correcta = campos.respuesta_correcta.trim()
      if (correcta === '') encontrados.respuesta_correcta = 'La respuesta correcta es obligatoria'
      propiosDelTipo.tolerancia = campos.tolerancia
      propiosDelTipo.respuesta_correcta = correcta
    }

    if (Object.keys(encontrados).length > 0) {
      setErrores(encontrados)
      setError(AVISO_ERRORES)
      document.getElementById(ORDEN_CAMPOS.find((campo) => encontrados[campo]))?.focus()
      return
    }

    setErrores({})
    setEnviando(true)
    try {
      await alGuardar({
        enunciado,
        tipo: campos.tipo,
        // Sin objeto asociado se manda null, no el texto vacio del selector.
        objeto_id: campos.objeto_id === '' ? null : Number(campos.objeto_id),
        ...propiosDelTipo,
      })
    } catch (err) {
      if (err.status === 401) {
        cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        return
      }
      if (err.status === 400 && err.errores) {
        setErrores(err.errores)
        setError(AVISO_ERRORES)
        return
      }
      setError(err.message)
    } finally {
      setEnviando(false)
    }
  }

  function propsDe(id, { obligatorio = true, ayuda = false } = {}) {
    const describe = [ayuda && `${id}-ayuda`, errores[id] && `${id}-error`].filter(Boolean).join(' ')
    return {
      id,
      name: id,
      value: campos[id],
      onChange: cambiar,
      'aria-required': obligatorio ? 'true' : undefined,
      'aria-invalid': errores[id] ? true : undefined,
      'aria-describedby': describe || undefined,
      className: `w-full rounded-md border px-3 py-2 focus:outline-none ${
        errores[id]
          ? 'border-red-500 bg-red-50 focus:border-red-700'
          : 'border-stone-300 focus:border-stone-900'
      }`,
    }
  }

  return (
    <>
      {error && (
        <p role="alert" className="mb-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}

      <form onSubmit={enviar} noValidate className="space-y-5">
        <Campo id="enunciado" etiqueta="Enunciado" obligatorio error={errores.enunciado}>
          <textarea {...propsDe('enunciado')} rows={3} />
        </Campo>

        <Campo
          id="tipo"
          etiqueta="Tipo de desafío"
          obligatorio
          ayuda="Cada tipo pide sus propios datos, que aparecen abajo."
          error={errores.tipo}
        >
          <select {...propsDe('tipo', { ayuda: true })}>
            <option value="">Elegí un tipo</option>
            {TIPOS_DESAFIO.map(([valor, nombre]) => (
              <option key={valor} value={valor}>
                {nombre}
              </option>
            ))}
          </select>
        </Campo>

        {/* Bloque propio del tipo elegido (ADM09). Al cambiar el tipo se
            muestra el del tipo nuevo y se manda solo lo de ese tipo. */}
        {campos.tipo === 'pregunta_opcion_multiple' && (
          <fieldset>
            <legend className="mb-1 text-sm font-medium">
              Opciones de respuesta
              <span aria-hidden="true" className="ml-0.5 text-red-600">
                *
              </span>
            </legend>
            <p className="mb-2 text-sm text-stone-500">
              Entre {MINIMO_OPCIONES} y {MAXIMO_OPCIONES}. Marcá el círculo de la opción correcta.
            </p>
            <div className="space-y-2">
              {campos.opciones.map((opcion, indice) => (
                // El indice alcanza como key: las opciones se identifican por
                // su posicion y la lista no se reordena.
                <div key={indice} className="flex items-center gap-2">
                  {/* La marca de "correcta" viaja con el texto de la opcion,
                      que es lo que se guarda (ADM12). Una opcion vacia no se
                      puede marcar: no llegaria a guardarse. */}
                  <input
                    id={indice === 0 ? 'respuesta_correcta' : undefined}
                    type="radio"
                    name="respuesta_correcta"
                    checked={opcion !== '' && campos.respuesta_correcta === opcion}
                    onChange={() => marcarCorrecta(opcion)}
                    disabled={opcion.trim() === ''}
                    aria-label={`La opción ${indice + 1} es la correcta`}
                    className="size-4 shrink-0"
                  />
                  <input
                    // La primera lleva el id del grupo, para que el foco al
                    // primer campo con error caiga en un campo de verdad.
                    id={indice === 0 ? 'opciones' : undefined}
                    value={opcion}
                    onChange={(evento) => cambiarOpcion(indice, evento.target.value)}
                    aria-label={`Opción ${indice + 1}`}
                    aria-invalid={errores.opciones ? true : undefined}
                    className={`w-full rounded-md border px-3 py-2 focus:outline-none ${
                      errores.opciones
                        ? 'border-red-500 bg-red-50 focus:border-red-700'
                        : 'border-stone-300 focus:border-stone-900'
                    }`}
                  />
                  {campos.opciones.length > MINIMO_OPCIONES && (
                    <button
                      type="button"
                      onClick={() => quitarOpcion(indice)}
                      aria-label={`Quitar la opción ${indice + 1}`}
                      className="rounded-md border border-stone-300 px-3 py-2 text-sm font-medium hover:bg-stone-100"
                    >
                      Quitar
                    </button>
                  )}
                </div>
              ))}
            </div>
            {campos.opciones.length < MAXIMO_OPCIONES && (
              <button
                type="button"
                onClick={agregarOpcion}
                className="mt-2 rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
              >
                Agregar opción
              </button>
            )}
            {errores.opciones && (
              <p className="mt-1 text-sm font-medium text-red-700">{errores.opciones}</p>
            )}
            {errores.respuesta_correcta && (
              <p className="mt-1 text-sm font-medium text-red-700">{errores.respuesta_correcta}</p>
            )}
          </fieldset>
        )}

        {campos.tipo === 'respuesta_corta' && (
          <>
            <Campo
              id="respuesta_correcta"
              etiqueta="Respuesta correcta"
              obligatorio
              error={errores.respuesta_correcta}
            >
              <input {...propsDe('respuesta_correcta')} />
            </Campo>

            <Campo
              id="tolerancia"
              etiqueta="Comparación de la respuesta"
              ayuda="Cómo se compara lo que escribe el visitante con la respuesta correcta."
              error={errores.tolerancia}
            >
              <select {...propsDe('tolerancia', { ayuda: true })}>
                <option value="flexible">Flexible: ignora mayúsculas, acentos y espacios de más</option>
                <option value="exacta">Exacta: tiene que escribirse igual</option>
              </select>
            </Campo>
          </>
        )}

        {TIPOS_CON_OBJETO.includes(campos.tipo) && (
          <p className="rounded-md bg-stone-100 px-3 py-2 text-sm text-stone-600">
            Este tipo no lleva respuesta escrita: se resuelve encontrando la pieza y escaneando su
            código.
          </p>
        )}

        <Campo
          id="objeto_id"
          etiqueta="Objeto del museo"
          obligatorio={TIPOS_CON_OBJETO.includes(campos.tipo)}
          opcional={!TIPOS_CON_OBJETO.includes(campos.tipo)}
          ayuda={
            TIPOS_CON_OBJETO.includes(campos.tipo)
              ? 'Es la pieza que el visitante tiene que encontrar y escanear.'
              : undefined
          }
          error={errores.objeto_id}
        >
          <select
            {...propsDe('objeto_id', {
              obligatorio: TIPOS_CON_OBJETO.includes(campos.tipo),
              ayuda: TIPOS_CON_OBJETO.includes(campos.tipo),
            })}
            disabled={!objetos}
          >
            <option value="">
              {!objetos
                ? 'Cargando objetos…'
                : TIPOS_CON_OBJETO.includes(campos.tipo)
                  ? 'Elegí el objeto'
                  : 'Sin objeto asociado'}
            </option>
            {objetos?.map((objeto) => (
              <option key={objeto.id} value={objeto.id}>
                {objeto.nombre} ({objeto.codigo}){objeto.activo ? '' : ' — dado de baja'}
              </option>
            ))}
          </select>
        </Campo>

        <div className="flex gap-2">
          <button
            type="submit"
            disabled={enviando}
            className="rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700 disabled:opacity-60"
          >
            {enviando ? textoEnviando : textoBoton}
          </button>
          {alCancelar && (
            <button
              type="button"
              onClick={alCancelar}
              disabled={enviando}
              className="rounded-md border border-stone-300 px-4 py-2 font-medium hover:bg-stone-100 disabled:opacity-60"
            >
              Cancelar
            </button>
          )}
        </div>
      </form>
    </>
  )
}
