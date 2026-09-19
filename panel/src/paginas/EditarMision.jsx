import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router'
import { pedir } from '../api.js'
import { camposDesdeMision } from '../camposMision.js'
import FormularioMision from '../componentes/FormularioMision.jsx'
import { formatearFecha } from '../fechas.js'
import { useSesion } from '../sesion/contexto.js'

export default function EditarMision() {
  const { id } = useParams()
  // Con los botones atras y adelante del navegador se puede pasar de editar
  // una mision a editar otra sin salir de esta pantalla, y React reutilizaria
  // el mismo componente con los datos de la anterior. La key con el id hace
  // que se arme de cero para cada mision.
  return <EditorDeMision key={id} id={id} />
}

function EditorDeMision({ id }) {
  const { token, cerrarSesion } = useSesion()

  const [mision, setMision] = useState(null)
  const [error, setError] = useState('')
  const [resultado, setResultado] = useState(null)
  // Cambia en cada guardado para volver a montar el formulario con los datos
  // que devolvio la API, que pueden diferir de lo escrito (espacios recortados).
  const [version, setVersion] = useState(0)

  useEffect(() => {
    let vigente = true
    pedir(`/misiones/${id}`, { token })
      .then(({ mision }) => vigente && setMision(mision))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(err.message)
      })
    return () => {
      vigente = false
    }
  }, [id, token, cerrarSesion])

  async function guardar(cuerpo) {
    const respuesta = await pedir(`/misiones/${id}`, { metodo: 'PUT', token, cuerpo })
    setMision(respuesta.mision)
    setResultado(respuesta.modificada ? 'guardada' : 'sin-cambios')
    setVersion((v) => v + 1)
  }

  const volver = (
    <Link to="/misiones" className="text-sm font-medium text-stone-600 hover:text-stone-900">
      ← Volver al listado
    </Link>
  )

  if (error) {
    return (
      <div className="max-w-2xl space-y-4">
        {volver}
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      </div>
    )
  }

  if (!mision) return <p className="text-stone-500">Cargando misión…</p>

  return (
    <div className="max-w-2xl">
      {volver}
      <h1 className="mt-2 text-2xl font-semibold">Editar misión</h1>
      <p className="mb-4 text-sm text-stone-600">
        Creada el {formatearFecha(mision.creada_en)} · Última modificación:{' '}
        {formatearFecha(mision.actualizada_en)}
        <br />
        Los desafíos asociados a la misión no se modifican al guardar estos datos.
      </p>

      <Link
        to={`/misiones/${id}/desafios`}
        className="mb-6 inline-block rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
      >
        Desafíos de la misión
      </Link>

      {resultado === 'guardada' && (
        <p role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 font-medium text-green-900">
          Cambios guardados.
        </p>
      )}
      {resultado === 'sin-cambios' && (
        <p role="status" className="mb-6 rounded-lg border border-stone-200 bg-stone-100 p-4 text-stone-700">
          No había cambios para guardar.
        </p>
      )}

      <FormularioMision
        key={version}
        valoresIniciales={camposDesdeMision(mision)}
        alGuardar={guardar}
        alIntentarGuardar={() => setResultado(null)}
        textoBoton="Guardar cambios"
        textoEnviando="Guardando…"
      />
    </div>
  )
}
