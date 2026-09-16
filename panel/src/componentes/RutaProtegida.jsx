import { Navigate, Outlet, useLocation } from 'react-router'
import { useSesion } from '../sesion/contexto.js'

// Envuelve las pantallas que requieren sesion. Sin sesion redirige al login
// y recuerda a donde se queria ir, para volver ahi despues de ingresar.
export default function RutaProtegida() {
  const { usuario } = useSesion()
  const ubicacion = useLocation()

  if (!usuario) {
    return <Navigate to="/login" replace state={{ desde: ubicacion.pathname }} />
  }
  return <Outlet />
}
