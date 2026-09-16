import { useState } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'
import { useSesion } from '../sesion/contexto.js'

export default function Login() {
  const { usuario, aviso, iniciarSesion } = useSesion()
  const navegar = useNavigate()
  const ubicacion = useLocation()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  const destino = ubicacion.state?.desde ?? '/misiones/nueva'

  // Con sesion activa no tiene sentido mostrar el login.
  if (usuario) return <Navigate to={destino} replace />

  async function enviar(evento) {
    evento.preventDefault()
    setError('')
    setEnviando(true)
    try {
      await iniciarSesion(email, password)
      navegar(destino, { replace: true })
    } catch (err) {
      setError(err.message)
      setEnviando(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-stone-50 px-4 text-stone-900">
      <div className="w-full max-w-sm">
        <p className="text-sm text-stone-500">Exploradores del Museo</p>
        <h1 className="mb-6 text-2xl font-semibold">Panel de administración</h1>

        <form onSubmit={enviar} className="space-y-4 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          {aviso && !error && (
            <p className="rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-800">{aviso}</p>
          )}
          {error && (
            <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </p>
          )}

          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium">
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-md border border-stone-300 px-3 py-2 focus:border-stone-900 focus:outline-none"
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium">
              Contraseña
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-md border border-stone-300 px-3 py-2 focus:border-stone-900 focus:outline-none"
            />
          </div>

          <button
            type="submit"
            disabled={enviando}
            className="w-full rounded-md bg-stone-900 px-4 py-2 font-medium text-white hover:bg-stone-700 disabled:opacity-60"
          >
            {enviando ? 'Ingresando…' : 'Ingresar'}
          </button>
        </form>
      </div>
    </div>
  )
}
