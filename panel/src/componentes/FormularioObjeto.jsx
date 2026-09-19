import { useEffect, useState } from 'react'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'
import { validarObjeto } from '../validaciones/objeto.js'
import Campo from './Campo.jsx'

// Formulario de datos de un objeto, compartido por el alta y la edicion
// (ADM15). Funciona igual que FormularioMision y recibe las mismas props:
// valoresIniciales, alGuardar, alIntentarGuardar, textoBoton, textoEnviando
// y reiniciarAlGuardar.
//
// Carga por su cuenta la lista de salas para el selector, porque la
// necesitan las dos pantallas que lo usan.

const ORDEN_CAMPOS = ['nombre', 'sala_id', 'dato_clave']
const AVISO_ERRORES = 'Revisá los campos marcados.'

export default function FormularioObjeto({
  valoresIniciales,
  alGuardar,
  alIntentarGuardar,
  textoBoton,
  textoEnviando,
  reiniciarAlGuardar = false,
}) {
  const { token, cerrarSesion } = useSesion()

  const [salas, setSalas] = useState(null)
  const [errorSalas, setErrorSalas] = useState('')
  const [campos, setCampos] = useState(valoresIniciales)
  const [errores, setErrores] = useState({})
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  useEffect(() => {
    let vigente = true
    pedir('/salas', { token })
      .then(({ salas }) => vigente && setSalas(salas))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setErrorSalas(`No se pudieron cargar las salas: ${err.message}`)
      })
    return () => {
      vigente = false
    }
  }, [token, cerrarSesion])

  function cambiar(evento) {
    const { name, value } = evento.target
    setCampos({ ...campos, [name]: value })
    // Al corregir un campo se quita su mensaje, sin esperar a enviar de nuevo.
    if (errores[name]) {
      const { [name]: _quitado, ...resto } = errores
      setErrores(resto)
      if (Object.keys(resto).length === 0 && error === AVISO_ERRORES) setError('')
    }
  }

  function mostrarErrores(nuevos) {
    setErrores(nuevos)
    setError(AVISO_ERRORES)
    const primero = ORDEN_CAMPOS.find((campo) => nuevos[campo])
    document.getElementById(primero)?.focus()
  }

  async function enviar(evento) {
    evento.preventDefault()
    setError('')
    alIntentarGuardar?.()

    const { errores: encontrados, cuerpo } = validarObjeto(campos)
    if (Object.keys(encontrados).length > 0) {
      mostrarErrores(encontrados)
      return
    }

    setErrores({})
    setEnviando(true)
    try {
      await alGuardar(cuerpo)
      if (reiniciarAlGuardar) setCampos(valoresIniciales)
    } catch (err) {
      if (err.status === 401) {
        cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        return
      }
      if (err.status === 400 && err.errores) {
        mostrarErrores(err.errores)
        return
      }
      setError(err.message)
    } finally {
      setEnviando(false)
    }
  }

  function propsDe(id, { ayuda = false } = {}) {
    const describe = [ayuda && `${id}-ayuda`, errores[id] && `${id}-error`].filter(Boolean).join(' ')
    return {
      id,
      name: id,
      value: campos[id],
      onChange: cambiar,
      'aria-required': 'true',
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
      {(error || errorSalas) && (
        <p role="alert" className="mb-6 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error || errorSalas}
        </p>
      )}

      <form
        onSubmit={enviar}
        noValidate
        className="space-y-5 rounded-lg border border-stone-200 bg-white p-6 shadow-sm"
      >
        <p className="text-sm text-stone-500">
          Los campos marcados con <span className="text-red-600">*</span> son obligatorios.
        </p>

        <Campo id="nombre" etiqueta="Nombre" obligatorio error={errores.nombre}>
          <input {...propsDe('nombre')} />
        </Campo>

        <Campo id="sala_id" etiqueta="Sala" obligatorio error={errores.sala_id}>
          <select {...propsDe('sala_id')} disabled={!salas}>
            <option value="">{salas ? 'Elegí una sala' : 'Cargando salas…'}</option>
            {salas?.map((sala) => (
              <option key={sala.id} value={sala.id}>
                {sala.nivel ? `${sala.nombre} (${sala.nivel})` : sala.nombre}
              </option>
            ))}
          </select>
        </Campo>

        <Campo
          id="dato_clave"
          etiqueta="Dato clave"
          obligatorio
          ayuda="Lo que ve el visitante al escanear el objeto. Sirve de base para las preguntas."
          error={errores.dato_clave}
        >
          <textarea {...propsDe('dato_clave', { ayuda: true })} rows={3} />
        </Campo>

        <button
          type="submit"
          disabled={enviando || !salas}
          className="rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700 disabled:opacity-60"
        >
          {enviando ? textoEnviando : textoBoton}
        </button>
      </form>
    </>
  )
}
