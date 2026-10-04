import { Fragment, useEffect, useState } from 'react'
import { Link } from 'react-router'
import { pedir } from '../api.js'
import { useSesion } from '../sesion/contexto.js'

export default function ListaObjetos() {
  const { token, cerrarSesion } = useSesion()
  const [objetos, setObjetos] = useState(null)
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  // Id del objeto cuyo estado se esta cambiando, para desactivar su boton
  // mientras tanto y que un doble clic no mande dos pedidos.
  const [cambiando, setCambiando] = useState(null)
  // Id del objeto que espera confirmacion para borrarse, y el que se esta
  // borrando en este momento.
  const [confirmando, setConfirmando] = useState(null)
  const [borrando, setBorrando] = useState(null)

  useEffect(() => {
    let vigente = true
    pedir('/objetos', { token })
      .then(({ objetos }) => vigente && setObjetos(objetos))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(err.message)
      })
    return () => {
      vigente = false
    }
  }, [token, cerrarSesion])

  // Da de baja o reactiva un objeto. La baja no borra nada: el objeto queda
  // registrado y se puede reactivar, por eso no se pide confirmacion.
  async function cambiarEstado(objeto) {
    setError('')
    setCambiando(objeto.id)
    try {
      const respuesta = await pedir(`/objetos/${objeto.id}/estado`, {
        metodo: 'PATCH',
        token,
        cuerpo: { activo: !objeto.activo },
      })
      setObjetos((actuales) => actuales.map((o) => (o.id === objeto.id ? respuesta.objeto : o)))
    } catch (err) {
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else setError(`No se pudo cambiar el estado de “${objeto.nombre}”: ${err.message}`)
    } finally {
      setCambiando(null)
    }
  }

  // Borrado real, a diferencia de la baja. La API lo rechaza con 409 si algun
  // desafio usa el objeto: ahi se explica por que y se ofrece la baja.
  async function borrar(objeto) {
    setError('')
    setBorrando(objeto.id)
    try {
      await pedir(`/objetos/${objeto.id}`, { metodo: 'DELETE', token })
      setObjetos((actuales) => actuales.filter((o) => o.id !== objeto.id))
      setConfirmando(null)
      setAviso(`Objeto “${objeto.nombre}” borrado.`)
    } catch (err) {
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else if (err.status === 409) {
        const cuantos = err.datos?.desafios
        setError(
          `No se puede borrar “${objeto.nombre}”: se usa en ${
            cuantos ? `${cuantos} desafío${cuantos > 1 ? 's' : ''}` : 'algún desafío'
          }. Si ya no está en el museo, dalo de baja.`
        )
        setConfirmando(null)
      } else setError(`No se pudo borrar “${objeto.nombre}”: ${err.message}`)
    } finally {
      setBorrando(null)
    }
  }

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Objetos del museo</h1>
          <p className="text-stone-600">Las piezas registradas, en el orden del recorrido por las salas.</p>
        </div>
        <Link
          to="/objetos/nuevo"
          className="rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700"
        >
          Nuevo objeto
        </Link>
      </div>

      {error && (
        <p role="alert" className="mb-6 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}

      {aviso && (
        <p role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 font-medium text-green-900">
          {aviso}
        </p>
      )}

      {objetos === null && !error && <p className="text-stone-500">Cargando objetos…</p>}

      {objetos?.length === 0 && (
        <p className="rounded-lg border border-dashed border-stone-300 bg-white p-8 text-center text-stone-600">
          Todavía no hay objetos registrados.
        </p>
      )}

      {objetos?.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-stone-200 bg-white shadow-sm">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-stone-200 bg-stone-50 text-stone-600">
              <tr>
                <th scope="col" className="px-4 py-3 font-medium">Nombre</th>
                <th scope="col" className="px-4 py-3 font-medium">Sala</th>
                <th scope="col" className="px-4 py-3 font-medium">Código</th>
                <th scope="col" className="px-4 py-3 font-medium">Identificador</th>
                <th scope="col" className="px-4 py-3 font-medium">Estado</th>
                <th scope="col" className="px-4 py-3 font-medium">
                  <span className="sr-only">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-stone-100">
              {objetos.map((objeto) => (
                // Cada objeto puede aportar dos filas: la suya y la de la
                // confirmacion de borrado. La key va en el fragmento.
                <Fragment key={objeto.id}>
                <tr className={objeto.activo ? '' : 'text-stone-500'}>
                  <td className="px-4 py-3 font-medium">{objeto.nombre}</td>
                  <td className="px-4 py-3">{objeto.sala}</td>
                  <td className="px-4 py-3 font-mono whitespace-nowrap">{objeto.codigo}</td>
                  <td className="px-4 py-3">{objeto.tipo_identificador === 'qr' ? 'QR' : 'NFC'}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap ${
                        objeto.activo ? 'bg-green-100 text-green-800' : 'bg-stone-100 text-stone-700'
                      }`}
                    >
                      {objeto.activo ? 'Activo' : 'Dado de baja'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Link
                        to={`/objetos/${objeto.id}/editar`}
                        aria-label={`Editar ${objeto.nombre}`}
                        className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium text-stone-900 hover:bg-stone-100"
                      >
                        Editar
                      </Link>
                      <button
                        type="button"
                        onClick={() => cambiarEstado(objeto)}
                        disabled={cambiando === objeto.id}
                        aria-label={`${objeto.activo ? 'Dar de baja' : 'Reactivar'} ${objeto.nombre}`}
                        className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium whitespace-nowrap text-stone-900 hover:bg-stone-100 disabled:opacity-60"
                      >
                        {objeto.activo ? 'Dar de baja' : 'Reactivar'}
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setAviso('')
                          setError('')
                          setConfirmando(objeto.id)
                        }}
                        aria-label={`Borrar ${objeto.nombre}`}
                        className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium text-stone-900 hover:bg-stone-100"
                      >
                        Borrar
                      </button>
                    </div>
                  </td>
                </tr>

                {confirmando === objeto.id && (
                  <tr>
                    <td colSpan={6} className="px-4 pb-3">
                      <div role="alert" className="rounded-md border border-amber-200 bg-amber-50 p-3">
                        <p className="text-sm text-amber-900">
                          “{objeto.nombre}” se borra de la base y no se puede deshacer. Si la pieza
                          dejó de exhibirse pero querés conservarla, usá “Dar de baja”.
                        </p>
                        <div className="mt-3 flex gap-2">
                          <button
                            type="button"
                            onClick={() => borrar(objeto)}
                            disabled={borrando === objeto.id}
                            className="rounded-md bg-stone-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-60"
                          >
                            {borrando === objeto.id ? 'Borrando…' : 'Sí, borrar'}
                          </button>
                          <button
                            type="button"
                            onClick={() => setConfirmando(null)}
                            disabled={borrando === objeto.id}
                            className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-white disabled:opacity-60"
                          >
                            Cancelar
                          </button>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
