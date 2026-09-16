import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { pedir } from '../api.js'
import { formatearFecha } from '../fechas.js'
import { useSesion } from '../sesion/contexto.js'

export default function ListaMisiones() {
  const { token, cerrarSesion } = useSesion()
  const [misiones, setMisiones] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    // Si el usuario sale de la pantalla antes de que llegue la respuesta, se
    // descarta: actualizar el estado de un componente que ya no esta en
    // pantalla no tiene efecto y solo genera confusion.
    let vigente = true
    pedir('/misiones', { token })
      .then(({ misiones }) => vigente && setMisiones(misiones))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(err.message)
      })
    return () => {
      vigente = false
    }
  }, [token, cerrarSesion])

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Misiones</h1>
          <p className="text-stone-600">Todas las misiones del museo, las modificadas recientemente primero.</p>
        </div>
        <Link
          to="/misiones/nueva"
          className="rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700"
        >
          Nueva misión
        </Link>
      </div>

      {error && (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}

      {!error && misiones === null && <p className="text-stone-500">Cargando misiones…</p>}

      {misiones?.length === 0 && (
        <p className="rounded-lg border border-dashed border-stone-300 bg-white p-8 text-center text-stone-600">
          Todavía no hay misiones cargadas.
        </p>
      )}

      {misiones?.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-stone-200 bg-white shadow-sm">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-stone-200 bg-stone-50 text-stone-600">
              <tr>
                <th scope="col" className="px-4 py-3 font-medium">Nombre</th>
                <th scope="col" className="px-4 py-3 font-medium">Duración</th>
                <th scope="col" className="px-4 py-3 font-medium">Estado</th>
                <th scope="col" className="px-4 py-3 font-medium">Última modificación</th>
                <th scope="col" className="px-4 py-3 font-medium">
                  <span className="sr-only">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-stone-100">
              {misiones.map((mision) => (
                <tr key={mision.id}>
                  <td className="px-4 py-3 font-medium">{mision.nombre}</td>
                  <td className="px-4 py-3 whitespace-nowrap">{mision.duracion_estimada} min</td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        mision.activa ? 'bg-green-100 text-green-800' : 'bg-stone-100 text-stone-700'
                      }`}
                    >
                      {mision.activa ? 'Activa' : 'Inactiva'}
                    </span>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-stone-600">
                    {formatearFecha(mision.actualizada_en)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {/* aria-label: un lector de pantalla leeria "Editar" en todas
                        las filas sin decir cual mision; asi dice el nombre. */}
                    <Link
                      to={`/misiones/${mision.id}/editar`}
                      aria-label={`Editar ${mision.nombre}`}
                      className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
                    >
                      Editar
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
