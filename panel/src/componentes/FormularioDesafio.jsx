import { useEffect, useState } from 'react'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'
import { TIPOS_DESAFIO } from '../tiposDesafio.js'
import Campo from './Campo.jsx'

// Formulario de un desafio, compartido por el alta y la edicion (ADM08).
// Los campos propios de cada tipo son de ADM09 y la respuesta correcta de
// ADM12: todavia no estan.
//
// Props:
// - valoresIniciales: { enunciado, tipo, objeto_id }, todos como texto.
// - alGuardar(cuerpo): envia los datos a la API.
// - textoBoton / textoEnviando.
// - alCancelar: si viene, muestra un boton Cancelar (se usa al editar).

const ORDEN_CAMPOS = ['enunciado', 'tipo', 'objeto_id']
const AVISO_ERRORES = 'Revisá los campos marcados.'

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

  async function enviar(evento) {
    evento.preventDefault()
    setError('')

    // Las mismas reglas que la API, que es la que manda.
    const encontrados = {}
    const enunciado = campos.enunciado.trim()
    if (enunciado === '') encontrados.enunciado = 'El enunciado es obligatorio'
    if (campos.tipo === '') encontrados.tipo = 'El tipo de desafío es obligatorio'

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

  function propsDe(id, { obligatorio = true } = {}) {
    return {
      id,
      name: id,
      value: campos[id],
      onChange: cambiar,
      'aria-required': obligatorio ? 'true' : undefined,
      'aria-invalid': errores[id] ? true : undefined,
      'aria-describedby': errores[id] ? `${id}-error` : undefined,
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

        <Campo id="tipo" etiqueta="Tipo de desafío" obligatorio error={errores.tipo}>
          <select {...propsDe('tipo')}>
            <option value="">Elegí un tipo</option>
            {TIPOS_DESAFIO.map(([valor, nombre]) => (
              <option key={valor} value={valor}>
                {nombre}
              </option>
            ))}
          </select>
        </Campo>

        <Campo id="objeto_id" etiqueta="Objeto del museo" opcional error={errores.objeto_id}>
          <select {...propsDe('objeto_id', { obligatorio: false })} disabled={!objetos}>
            <option value="">{objetos ? 'Sin objeto asociado' : 'Cargando objetos…'}</option>
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
