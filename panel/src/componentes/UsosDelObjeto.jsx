import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'
import { nombreDeTipo } from '../tiposDesafio.js'

// En que desafios se usa un objeto (ADM18). La API ya los devuelve agrupables:
// vienen ordenados por mision, asi que alcanza con juntarlos en el orden en
// que llegan.
function agruparPorMision(desafios) {
  const misiones = []
  for (const desafio of desafios) {
    const ultima = misiones.at(-1)
    if (ultima?.id === desafio.mision_id) ultima.desafios.push(desafio)
    else {
      misiones.push({
        id: desafio.mision_id,
        nombre: desafio.mision,
        archivada: desafio.archivada,
        desafios: [desafio],
      })
    }
  }
  return misiones
}

export default function UsosDelObjeto({ objetoId }) {
  const { token, cerrarSesion } = useSesion()
  const [desafios, setDesafios] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let vigente = true
    pedir(`/objetos/${objetoId}/desafios`, { token })
      .then(({ desafios }) => vigente && setDesafios(desafios))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(`No se pudo averiguar dónde se usa el objeto: ${err.message}`)
      })
    return () => {
      vigente = false
    }
  }, [objetoId, token, cerrarSesion])

  return (
    <section className="mb-6 rounded-lg border border-stone-200 bg-white p-4 shadow-sm">
      <h2 className="font-semibold">Dónde se usa</h2>

      {error && (
        <p role="alert" className="mt-2 text-sm text-red-700">
          {error}
        </p>
      )}
      {desafios === null && !error && <p className="mt-2 text-sm text-stone-500">Buscando…</p>}

      {desafios?.length === 0 && (
        <p className="mt-2 text-sm text-stone-600">
          Ningún desafío usa este objeto todavía. Se puede borrar sin dejar desafíos rotos.
        </p>
      )}

      {desafios?.length > 0 && (
        <>
          <p className="mt-2 text-sm text-stone-600">
            Se usa en {desafios.length} {desafios.length === 1 ? 'desafío' : 'desafíos'}. Mientras
            tanto no se puede borrar; si la pieza dejó de exhibirse, dala de baja.
          </p>
          <ul className="mt-3 space-y-3">
            {agruparPorMision(desafios).map((mision) => (
              <li key={mision.id}>
                <p className="text-sm font-medium">
                  {/* Una mision archivada no se enlaza: su pantalla de
                      desafios responde 404 hasta que se la desarchive. */}
                  {mision.archivada ? (
                    <>
                      {mision.nombre}
                      <span className="ml-2 rounded-full bg-stone-100 px-2 py-0.5 text-xs font-medium text-stone-700">
                        Archivada
                      </span>
                    </>
                  ) : (
                    <Link to={`/misiones/${mision.id}/desafios`} className="underline hover:text-stone-600">
                      {mision.nombre}
                    </Link>
                  )}
                </p>
                <ul className="mt-1 space-y-1">
                  {mision.desafios.map((desafio) => (
                    <li key={desafio.id} className="text-sm text-stone-600">
                      {desafio.orden}. {nombreDeTipo(desafio.tipo)} · {desafio.enunciado}
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
