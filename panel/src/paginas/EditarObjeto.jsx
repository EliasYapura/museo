import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router'
import { pedir } from '../api.js'
import { camposDesdeObjeto } from '../camposObjeto.js'
import FormularioObjeto from '../componentes/FormularioObjeto.jsx'
import IdentificadorObjeto from '../componentes/IdentificadorObjeto.jsx'
import VistaPreviaImagen from '../componentes/VistaPreviaImagen.jsx'
import { formatearFecha } from '../fechas.js'
import { useSesion } from '../sesion/contexto.js'

export default function EditarObjeto() {
  const { id } = useParams()
  // Igual que en EditarMision: la key arma la pantalla de cero para cada objeto.
  return <EditorDeObjeto key={id} id={id} />
}

function EditorDeObjeto({ id }) {
  const { token, cerrarSesion } = useSesion()

  const [objeto, setObjeto] = useState(null)
  const [error, setError] = useState('')
  const [resultado, setResultado] = useState(null)
  const [version, setVersion] = useState(0)

  useEffect(() => {
    let vigente = true
    pedir(`/objetos/${id}`, { token })
      .then(({ objeto }) => vigente && setObjeto(objeto))
      .catch((err) => {
        if (!vigente) return
        if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
        else setError(err.message)
      })
    return () => {
      vigente = false
    }
  }, [id, token, cerrarSesion])

  async function regenerarCodigo() {
    try {
      const { objeto: actualizado } = await pedir(`/objetos/${id}/codigo`, { metodo: 'PATCH', token })
      setObjeto(actualizado)
      setResultado('codigo-nuevo')
    } catch (err) {
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else throw err
    }
  }

  async function guardar(cuerpo) {
    const respuesta = await pedir(`/objetos/${id}`, { metodo: 'PUT', token, cuerpo })
    setObjeto(respuesta.objeto)
    setResultado(respuesta.modificado ? 'guardado' : 'sin-cambios')
    setVersion((v) => v + 1)
  }

  const volver = (
    <Link to="/objetos" className="text-sm font-medium text-stone-600 hover:text-stone-900">
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

  if (!objeto) return <p className="text-stone-500">Cargando objeto…</p>

  return (
    <div className="max-w-2xl">
      {volver}
      <h1 className="mt-2 text-2xl font-semibold">Editar objeto</h1>
      <p className="mb-6 text-sm text-stone-600">
        Registrado el {formatearFecha(objeto.creado_en)} ·{' '}
        {objeto.activo ? 'Activo' : 'Dado de baja'}
        <br />
        El código no se modifica al guardar los datos.
      </p>

      <IdentificadorObjeto objeto={objeto} alRegenerar={regenerarCodigo} />

      {objeto.imagen_url && (
        <div className="mb-6">
          <VistaPreviaImagen key={objeto.imagen_url} url={objeto.imagen_url} descripcion={objeto.nombre} />
        </div>
      )}

      {resultado === 'guardado' && (
        <p role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 font-medium text-green-900">
          Cambios guardados.
        </p>
      )}
      {resultado === 'codigo-nuevo' && (
        <p role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 font-medium text-green-900">
          Código nuevo generado. Reemplazá la etiqueta que está junto a la pieza.
        </p>
      )}
      {resultado === 'sin-cambios' && (
        <p role="status" className="mb-6 rounded-lg border border-stone-200 bg-stone-100 p-4 text-stone-700">
          No había cambios para guardar.
        </p>
      )}

      <FormularioObjeto
        key={version}
        valoresIniciales={camposDesdeObjeto(objeto)}
        alGuardar={guardar}
        alIntentarGuardar={() => setResultado(null)}
        textoBoton="Guardar cambios"
        textoEnviando="Guardando…"
      />
    </div>
  )
}
