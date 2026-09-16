import { useState } from 'react'
import { pedir } from '../api.js'
import { CAMPOS_VACIOS } from '../camposMision.js'
import FormularioMision from '../componentes/FormularioMision.jsx'
import { useSesion } from '../sesion/contexto.js'

export default function NuevaMision() {
  const { token } = useSesion()
  const [creada, setCreada] = useState(null)

  async function crear(cuerpo) {
    const { mision } = await pedir('/misiones', { metodo: 'POST', token, cuerpo })
    setCreada(mision)
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

      <FormularioMision
        valoresIniciales={CAMPOS_VACIOS}
        alGuardar={crear}
        alIntentarGuardar={() => setCreada(null)}
        textoBoton="Crear misión"
        textoEnviando="Guardando…"
        reiniciarAlGuardar
      />
    </div>
  )
}
