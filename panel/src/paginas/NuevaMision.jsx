import { useState } from 'react'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'
import { DURACION_MAXIMA, DURACION_MINIMA, validarMision } from '../validaciones/mision.js'

// Los nombres de los campos son los mismos que usa la API, asi los errores
// que devuelve el servidor se asignan a cada campo sin traducir nombres.
const VACIO = { nombre: '', descripcion: '', duracion_estimada: '', imagen_url: '' }
const ORDEN_CAMPOS = ['nombre', 'descripcion', 'duracion_estimada', 'imagen_url']
const AVISO_ERRORES = 'Revisá los campos marcados.'

// Etiqueta, ayuda y mensaje de error de un campo. El error se vincula al
// campo con aria-describedby, para que un lector de pantalla lo anuncie.
function Campo({ id, etiqueta, obligatorio, opcional, ayuda, error, children }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-sm font-medium">
        {etiqueta}
        {obligatorio && (
          <span aria-hidden="true" className="ml-0.5 text-red-600">
            *
          </span>
        )}
        {opcional && <span className="font-normal text-stone-500"> (opcional)</span>}
      </label>
      {children}
      {ayuda && (
        <p id={`${id}-ayuda`} className="mt-1 text-sm text-stone-500">
          {ayuda}
        </p>
      )}
      {error && (
        <p id={`${id}-error`} className="mt-1 text-sm font-medium text-red-700">
          {error}
        </p>
      )}
    </div>
  )
}

export default function NuevaMision() {
  const { token, cerrarSesion } = useSesion()

  const [campos, setCampos] = useState(VACIO)
  const [errores, setErrores] = useState({})
  const [error, setError] = useState('')
  const [creada, setCreada] = useState(null)
  const [enviando, setEnviando] = useState(false)

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
    // Lleva el cursor al primer campo a corregir, en el orden del formulario.
    const primero = ORDEN_CAMPOS.find((campo) => nuevos[campo])
    document.getElementById(primero)?.focus()
  }

  async function enviar(evento) {
    evento.preventDefault()
    setError('')
    setCreada(null)

    const duracionIlegible = document.getElementById('duracion_estimada').validity.badInput
    const { errores: encontrados, cuerpo } = validarMision(campos, { duracionIlegible })
    if (Object.keys(encontrados).length > 0) {
      mostrarErrores(encontrados)
      return
    }

    setErrores({})
    setEnviando(true)
    try {
      const { mision } = await pedir('/misiones', { metodo: 'POST', token, cuerpo })
      setCreada(mision)
      setCampos(VACIO)
    } catch (err) {
      if (err.status === 401) {
        // El token vencio mientras se completaba el formulario. Al cerrar la
        // sesion, RutaProtegida redirige al login y recuerda volver aca.
        cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        return
      }
      // La API es la que tiene la ultima palabra: si rechaza un campo que el
      // panel dio por bueno, su mensaje tambien se muestra en ese campo.
      if (err.status === 400 && err.errores) {
        mostrarErrores(err.errores)
        return
      }
      setError(err.message)
    } finally {
      setEnviando(false)
    }
  }

  // Atributos comunes a todos los campos: valor, cambios y accesibilidad.
  function propsDe(id, { ayuda = false } = {}) {
    const describe = [ayuda && `${id}-ayuda`, errores[id] && `${id}-error`].filter(Boolean).join(' ')
    return {
      id,
      name: id,
      value: campos[id],
      onChange: cambiar,
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
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold">Nueva misión</h1>
      <p className="mb-6 text-stone-600">
        La misión se crea inactiva: los visitantes no la ven hasta que se active.
      </p>

      {creada && (
        <div role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 text-green-900">
          <p className="font-medium">Misión creada: “{creada.nombre}”</p>
          <p className="text-sm">
            Número {creada.id} · {creada.duracion_estimada} minutos · Estado:{' '}
            {creada.activa ? 'activa' : 'inactiva'}
          </p>
        </div>
      )}

      {error && (
        <p role="alert" className="mb-6 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}

      {/* noValidate desactiva los globos de error del navegador: su texto
          depende del idioma y del navegador de cada equipo, y no se pueden
          estilizar. Los mensajes los arma el panel. */}
      <form
        onSubmit={enviar}
        noValidate
        className="space-y-5 rounded-lg border border-stone-200 bg-white p-6 shadow-sm"
      >
        <p className="text-sm text-stone-500">
          Los campos marcados con <span className="text-red-600">*</span> son obligatorios.
        </p>

        <Campo id="nombre" etiqueta="Nombre" obligatorio error={errores.nombre}>
          <input {...propsDe('nombre')} aria-required="true" />
        </Campo>

        <Campo id="descripcion" etiqueta="Descripción" obligatorio error={errores.descripcion}>
          <textarea {...propsDe('descripcion')} aria-required="true" rows={4} />
        </Campo>

        <Campo
          id="duracion_estimada"
          etiqueta="Duración estimada (minutos)"
          obligatorio
          ayuda={`Entre ${DURACION_MINIMA} y ${DURACION_MAXIMA} minutos.`}
          error={errores.duracion_estimada}
        >
          <input
            {...propsDe('duracion_estimada', { ayuda: true })}
            aria-required="true"
            type="number"
            inputMode="numeric"
            min={DURACION_MINIMA}
            max={DURACION_MAXIMA}
            step={1}
            className={`${propsDe('duracion_estimada').className} max-w-40`}
          />
        </Campo>

        <Campo
          id="imagen_url"
          etiqueta="Imagen de portada"
          opcional
          ayuda="Dirección de una imagen ya publicada en internet."
          error={errores.imagen_url}
        >
          <input {...propsDe('imagen_url', { ayuda: true })} type="url" placeholder="https://…" />
        </Campo>

        <button
          type="submit"
          disabled={enviando}
          className="rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700 disabled:opacity-60"
        >
          {enviando ? 'Guardando…' : 'Crear misión'}
        </button>
      </form>
    </div>
  )
}
