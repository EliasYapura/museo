import { useState } from 'react'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'

const VACIO = { nombre: '', descripcion: '', duracion: '', imagen: '' }

export default function NuevaMision() {
  const { token, cerrarSesion } = useSesion()

  const [campos, setCampos] = useState(VACIO)
  const [error, setError] = useState('')
  const [creada, setCreada] = useState(null)
  const [enviando, setEnviando] = useState(false)

  const cambiar = (evento) => setCampos({ ...campos, [evento.target.name]: evento.target.value })

  async function enviar(evento) {
    evento.preventDefault()
    setError('')
    setCreada(null)
    setEnviando(true)
    try {
      const { mision } = await pedir('/misiones', {
        metodo: 'POST',
        token,
        cuerpo: {
          nombre: campos.nombre,
          descripcion: campos.descripcion,
          duracion_estimada: campos.duracion === '' ? null : Number(campos.duracion),
          imagen_url: campos.imagen,
        },
      })
      setCreada(mision)
      setCampos(VACIO)
    } catch (err) {
      if (err.status === 401) {
        // El token vencio mientras se completaba el formulario. Al cerrar la
        // sesion, RutaProtegida redirige al login y recuerda volver aca.
        cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        return
      }
      setError(err.message)
    } finally {
      setEnviando(false)
    }
  }

  const estiloCampo =
    'w-full rounded-md border border-stone-300 px-3 py-2 focus:border-stone-900 focus:outline-none'

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

      <form onSubmit={enviar} className="space-y-5 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
        <div>
          <label htmlFor="nombre" className="mb-1 block text-sm font-medium">
            Nombre
          </label>
          <input id="nombre" name="nombre" value={campos.nombre} onChange={cambiar} className={estiloCampo} />
        </div>

        <div>
          <label htmlFor="descripcion" className="mb-1 block text-sm font-medium">
            Descripción
          </label>
          <textarea
            id="descripcion"
            name="descripcion"
            rows={4}
            value={campos.descripcion}
            onChange={cambiar}
            className={estiloCampo}
          />
        </div>

        <div>
          <label htmlFor="duracion" className="mb-1 block text-sm font-medium">
            Duración estimada (minutos)
          </label>
          <input
            id="duracion"
            name="duracion"
            type="number"
            inputMode="numeric"
            value={campos.duracion}
            onChange={cambiar}
            className={`${estiloCampo} max-w-40`}
          />
        </div>

        <div>
          <label htmlFor="imagen" className="mb-1 block text-sm font-medium">
            Imagen de portada <span className="font-normal text-stone-500">(opcional)</span>
          </label>
          <input
            id="imagen"
            name="imagen"
            type="url"
            placeholder="https://…"
            value={campos.imagen}
            onChange={cambiar}
            className={estiloCampo}
          />
          <p className="mt-1 text-sm text-stone-500">Dirección de una imagen ya publicada en internet.</p>
        </div>

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
