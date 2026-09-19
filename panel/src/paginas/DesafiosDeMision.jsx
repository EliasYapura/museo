import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router'
import { pedir } from '../api.js'
import FormularioDesafio from '../componentes/FormularioDesafio.jsx'
import { useSesion } from '../sesion/contexto.js'
import { nombreDeTipo } from '../tiposDesafio.js'

const CAMPOS_VACIOS = { enunciado: '', tipo: '', objeto_id: '' }

const camposDesdeDesafio = (desafio) => ({
  enunciado: desafio.enunciado,
  tipo: desafio.tipo,
  objeto_id: desafio.objeto_id === null ? '' : String(desafio.objeto_id),
})

export default function DesafiosDeMision() {
  const { id } = useParams()
  // Igual que en las otras pantallas: la key arma todo de cero para cada mision.
  return <DesafiosDe key={id} misionId={id} />
}

function DesafiosDe({ misionId }) {
  const { token, cerrarSesion } = useSesion()

  const [mision, setMision] = useState(null)
  const [desafios, setDesafios] = useState(null)
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  // Id del desafio que se esta editando, o null si el formulario es de alta.
  const [editando, setEditando] = useState(null)
  const [borrando, setBorrando] = useState(null)

  // Se incrementa despues de agregar, para volver a armar el formulario
  // vacio y que no queden los datos del desafio recien creado.
  const [version, setVersion] = useState(0)

  useEffect(() => {
    let vigente = true
    pedir(`/misiones/${misionId}/desafios`, { token })
      .then(({ mision, desafios }) => {
        if (!vigente) return
        setMision(mision)
        setDesafios(desafios)
      })
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(err.message)
      })
    return () => {
      vigente = false
    }
  }, [misionId, token, cerrarSesion])

  async function agregar(cuerpo) {
    const { desafio } = await pedir(`/misiones/${misionId}/desafios`, {
      metodo: 'POST',
      token,
      cuerpo,
    })
    setDesafios((actuales) => [...actuales, desafio])
    setAviso(`Desafío agregado como número ${desafio.orden}.`)
    setVersion((v) => v + 1)
  }

  async function guardar(cuerpo) {
    const { desafio, modificado } = await pedir(`/desafios/${editando}`, {
      metodo: 'PUT',
      token,
      cuerpo,
    })
    setDesafios((actuales) => actuales.map((d) => (d.id === desafio.id ? desafio : d)))
    setEditando(null)
    setAviso(modificado ? 'Cambios guardados.' : 'No había cambios para guardar.')
  }

  async function borrar(desafio) {
    setError('')
    setBorrando(null)
    try {
      await pedir(`/desafios/${desafio.id}`, { metodo: 'DELETE', token })
      setDesafios((actuales) => actuales.filter((d) => d.id !== desafio.id))
      if (editando === desafio.id) setEditando(null)
      setAviso('Desafío borrado.')
    } catch (err) {
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else setError(`No se pudo borrar el desafío ${desafio.orden}: ${err.message}`)
    }
  }

  const enEdicion = desafios?.find((d) => d.id === editando)

  return (
    <div className="max-w-3xl">
      <Link to={`/misiones/${misionId}/editar`} className="text-sm font-medium text-stone-600 hover:text-stone-900">
        ← Volver a la misión
      </Link>
      <h1 className="mt-2 text-2xl font-semibold">Desafíos{mision ? ` de “${mision.nombre}”` : ''}</h1>
      <p className="mb-6 text-sm text-stone-600">
        Se resuelven en el orden en que aparecen. Los datos propios de cada tipo y la respuesta
        correcta se cargan más adelante.
      </p>

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

      {desafios === null && !error && <p className="text-stone-500">Cargando desafíos…</p>}

      {desafios?.length === 0 && (
        <p className="mb-6 rounded-lg border border-dashed border-stone-300 bg-white p-8 text-center text-stone-600">
          Esta misión todavía no tiene desafíos.
        </p>
      )}

      {desafios?.length > 0 && (
        <ol className="mb-6 space-y-3">
          {desafios.map((desafio) => (
            <li
              key={desafio.id}
              className="rounded-lg border border-stone-200 bg-white p-4 shadow-sm"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-sm text-stone-500">
                    {desafio.orden}. {nombreDeTipo(desafio.tipo)}
                    {desafio.objeto ? ` · ${desafio.objeto}` : ' · sin objeto asociado'}
                  </p>
                  <p className="font-medium">{desafio.enunciado}</p>
                </div>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setAviso('')
                      setBorrando(null)
                      setEditando(desafio.id)
                    }}
                    aria-label={`Editar el desafío ${desafio.orden}`}
                    className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
                  >
                    Editar
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setAviso('')
                      setBorrando(desafio.id)
                    }}
                    aria-label={`Borrar el desafío ${desafio.orden}`}
                    className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
                  >
                    Borrar
                  </button>
                </div>
              </div>

              {/* La confirmacion explica que el borrado no se puede deshacer. */}
              {borrando === desafio.id && (
                <div role="alert" className="mt-3 rounded-md border border-amber-200 bg-amber-50 p-3">
                  <p className="text-sm text-amber-900">
                    Se borra el desafío {desafio.orden} y sus pistas, y no se puede deshacer.
                  </p>
                  <div className="mt-3 flex gap-2">
                    <button
                      type="button"
                      onClick={() => borrar(desafio)}
                      className="rounded-md bg-stone-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-stone-700"
                    >
                      Sí, borrar
                    </button>
                    <button
                      type="button"
                      onClick={() => setBorrando(null)}
                      className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-white"
                    >
                      Cancelar
                    </button>
                  </div>
                </div>
              )}
            </li>
          ))}
        </ol>
      )}

      {desafios !== null && (
        <section className="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold">
            {enEdicion ? `Editar el desafío ${enEdicion.orden}` : 'Agregar un desafío'}
          </h2>
          {/* La key vuelve a armar el formulario al pasar de agregar a editar
              o de un desafio a otro, para que no queden datos del anterior. */}
          <FormularioDesafio
            key={editando ?? `nuevo-${version}`}
            valoresIniciales={enEdicion ? camposDesdeDesafio(enEdicion) : CAMPOS_VACIOS}
            alGuardar={enEdicion ? guardar : agregar}
            textoBoton={enEdicion ? 'Guardar cambios' : 'Agregar desafío'}
            textoEnviando="Guardando…"
            alCancelar={enEdicion ? () => setEditando(null) : undefined}
          />
        </section>
      )}
    </div>
  )
}
