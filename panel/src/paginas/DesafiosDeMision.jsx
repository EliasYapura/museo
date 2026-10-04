import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router'
import { pedir } from '../api.js'
import FormularioDesafio from '../componentes/FormularioDesafio.jsx'
import { useSesion } from '../sesion/contexto.js'
import { nombreDeTipo } from '../tiposDesafio.js'

const CAMPOS_VACIOS = {
  enunciado: '',
  tipo: '',
  objeto_id: '',
  puntos: '10', // el mismo valor por defecto que usa la API (ADM11)
  opciones: ['', ''], // el minimo que pide una pregunta de opcion multiple
  tolerancia: 'flexible',
  respuesta_correcta: '',
}

// La configuracion que corresponde a otro tipo no viene: esos campos toman su
// valor vacio, listos por si se cambia el tipo.
const camposDesdeDesafio = (desafio) => ({
  enunciado: desafio.enunciado,
  tipo: desafio.tipo,
  objeto_id: desafio.objeto_id === null ? '' : String(desafio.objeto_id),
  puntos: String(desafio.puntos),
  opciones: desafio.configuracion?.opciones ?? CAMPOS_VACIOS.opciones,
  tolerancia: desafio.configuracion?.tolerancia ?? CAMPOS_VACIOS.tolerancia,
  respuesta_correcta: desafio.respuesta_correcta ?? '',
})

// Resumen de lo propio del tipo, para no tener que abrir cada desafio.
function resumenDeConfiguracion(desafio) {
  const { opciones, tolerancia } = desafio.configuracion ?? {}
  if (desafio.tipo === 'pregunta_opcion_multiple' && opciones) {
    return `${opciones.length} opciones`
  }
  if (desafio.tipo === 'respuesta_corta' && tolerancia) {
    return tolerancia === 'exacta' ? 'comparación exacta' : 'comparación flexible'
  }
  return null
}

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
  // Mientras se guarda un orden nuevo se desactivan las flechas, para que dos
  // clics seguidos no manden dos listas distintas.
  const [moviendo, setMoviendo] = useState(false)

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
    // El numero que se avisa es la posicion en la lista, igual que el que se
    // ve en cada fila: la columna orden puede tener huecos de algun borrado.
    setAviso(`Desafío agregado como número ${desafios.length + 1}.`)
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

  async function borrar(desafio, posicion) {
    setError('')
    setBorrando(null)
    try {
      await pedir(`/desafios/${desafio.id}`, { metodo: 'DELETE', token })
      setDesafios((actuales) => actuales.filter((d) => d.id !== desafio.id))
      if (editando === desafio.id) setEditando(null)
      setAviso('Desafío borrado.')
    } catch (err) {
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else setError(`No se pudo borrar el desafío ${posicion}: ${err.message}`)
    }
  }

  // Mueve un desafio una posicion y manda la lista completa en el orden nuevo
  // (ADM10). La pantalla muestra el cambio antes de la respuesta para que la
  // flecha no se sienta trabada; si la API lo rechaza, se vuelve al anterior.
  async function mover(indice, salto) {
    const destino = indice + salto
    if (destino < 0 || destino >= desafios.length) return

    const anteriores = desafios
    const nuevos = [...desafios]
    nuevos[indice] = anteriores[destino]
    nuevos[destino] = anteriores[indice]

    setError('')
    setAviso('')
    setBorrando(null)
    setMoviendo(true)
    setDesafios(nuevos)
    try {
      const { desafios: guardados } = await pedir(`/misiones/${misionId}/desafios/orden`, {
        metodo: 'PUT',
        token,
        cuerpo: { ids: nuevos.map((d) => d.id) },
      })
      setDesafios(guardados)
    } catch (err) {
      setDesafios(anteriores)
      if (err.status === 401) cerrarSesion('Tu sesión venció. Ingresá de nuevo.')
      else setError(`No se pudo cambiar el orden: ${err.message}`)
    } finally {
      setMoviendo(false)
    }
  }

  const enEdicion = desafios?.find((d) => d.id === editando)
  // La posicion que se muestra sale del lugar en la lista y no de la columna
  // orden: asi el numero acompana al movimiento sin esperar la respuesta.
  const posicionEnEdicion = desafios?.findIndex((d) => d.id === editando) + 1

  return (
    <div className="max-w-3xl">
      <Link to={`/misiones/${misionId}/editar`} className="text-sm font-medium text-stone-600 hover:text-stone-900">
        ← Volver a la misión
      </Link>
      <h1 className="mt-2 text-2xl font-semibold">Desafíos{mision ? ` de “${mision.nombre}”` : ''}</h1>
      <div className="mb-6">
        <p className="text-sm text-stone-600">
          Se resuelven en el orden en que aparecen. Cada tipo pide sus propios datos y su respuesta
          correcta.
        </p>
        {/* Cuanto vale la mision entera, para poder equilibrar una con otra
            sin ir sumando desafio por desafio (ADM11). */}
        {desafios?.length > 0 && (
          <p className="mt-1 text-sm font-medium text-stone-700">
            {desafios.length} {desafios.length === 1 ? 'desafío' : 'desafíos'} ·{' '}
            {desafios.reduce((total, d) => total + d.puntos, 0)} puntos en total
          </p>
        )}
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

      {desafios === null && !error && <p className="text-stone-500">Cargando desafíos…</p>}

      {desafios?.length === 0 && (
        <p className="mb-6 rounded-lg border border-dashed border-stone-300 bg-white p-8 text-center text-stone-600">
          Esta misión todavía no tiene desafíos.
        </p>
      )}

      {desafios?.length > 0 && (
        <ol className="mb-6 space-y-3">
          {desafios.map((desafio, indice) => (
            <li
              key={desafio.id}
              className="rounded-lg border border-stone-200 bg-white p-4 shadow-sm"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-sm text-stone-500">
                    {[
                      `${indice + 1}. ${nombreDeTipo(desafio.tipo)}`,
                      `${desafio.puntos} ${desafio.puntos === 1 ? 'punto' : 'puntos'}`,
                      desafio.objeto ?? 'sin objeto asociado',
                      resumenDeConfiguracion(desafio),
                      desafio.respuesta_correcta
                        ? `respuesta: ${desafio.respuesta_correcta}`
                        : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  <p className="font-medium">{desafio.enunciado}</p>
                </div>
                <div className="flex gap-2">
                  {/* Las flechas solo tienen sentido con mas de un desafio. */}
                  {desafios.length > 1 && (
                    <div className="flex gap-1">
                      <button
                        type="button"
                        onClick={() => mover(indice, -1)}
                        disabled={moviendo || indice === 0}
                        aria-label={`Subir el desafío ${indice + 1}`}
                        className="rounded-md border border-stone-300 px-2.5 py-1.5 text-sm font-medium hover:bg-stone-100 disabled:opacity-40"
                      >
                        ↑
                      </button>
                      <button
                        type="button"
                        onClick={() => mover(indice, 1)}
                        disabled={moviendo || indice === desafios.length - 1}
                        aria-label={`Bajar el desafío ${indice + 1}`}
                        className="rounded-md border border-stone-300 px-2.5 py-1.5 text-sm font-medium hover:bg-stone-100 disabled:opacity-40"
                      >
                        ↓
                      </button>
                    </div>
                  )}
                  <button
                    type="button"
                    onClick={() => {
                      setAviso('')
                      setBorrando(null)
                      setEditando(desafio.id)
                    }}
                    aria-label={`Editar el desafío ${indice + 1}`}
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
                    aria-label={`Borrar el desafío ${indice + 1}`}
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
                    Se borra el desafío {indice + 1} y sus pistas, y no se puede deshacer.
                  </p>
                  <div className="mt-3 flex gap-2">
                    <button
                      type="button"
                      onClick={() => borrar(desafio, indice + 1)}
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
            {enEdicion ? `Editar el desafío ${posicionEnEdicion}` : 'Agregar un desafío'}
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
