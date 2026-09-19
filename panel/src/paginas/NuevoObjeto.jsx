import { useState } from 'react'
import { pedir } from '../api.js'
import { CAMPOS_VACIOS } from '../camposObjeto.js'
import FormularioObjeto from '../componentes/FormularioObjeto.jsx'
import { useSesion } from '../sesion/contexto.js'

export default function NuevoObjeto() {
  const { token } = useSesion()
  const [creado, setCreado] = useState(null)

  async function crear(cuerpo) {
    const { objeto } = await pedir('/objetos', { metodo: 'POST', token, cuerpo })
    setCreado(objeto)
  }

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold">Nuevo objeto</h1>
      <p className="mb-6 text-stone-600">
        Registrá una pieza del museo. El código que va a identificarla se genera automáticamente.
      </p>

      {creado && (
        <div role="status" className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 text-green-900">
          <p className="font-medium">Objeto registrado: “{creado.nombre}”</p>
          <p className="text-sm">
            Código <span className="font-mono">{creado.codigo}</span> · {creado.sala}
          </p>
        </div>
      )}

      <FormularioObjeto
        valoresIniciales={CAMPOS_VACIOS}
        alGuardar={crear}
        alIntentarGuardar={() => setCreado(null)}
        textoBoton="Registrar objeto"
        textoEnviando="Guardando…"
        reiniciarAlGuardar
      />
    </div>
  )
}
