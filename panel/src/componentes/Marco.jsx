import { NavLink, Outlet } from 'react-router'
import { useSesion } from '../sesion/contexto.js'

// Encabezado y navegacion comunes a todas las pantallas con sesion.
export default function Marco() {
  const { usuario, cerrarSesion } = useSesion()

  const estiloEnlace = ({ isActive }) =>
    `rounded-md px-3 py-2 text-sm font-medium ${
      isActive ? 'bg-stone-900 text-white' : 'text-stone-600 hover:bg-stone-100'
    }`

  return (
    <div className="min-h-screen bg-stone-50 text-stone-900">
      <header className="border-b border-stone-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-6 py-4">
          <div>
            <p className="text-sm text-stone-500">Exploradores del Museo</p>
            <p className="text-lg font-semibold">Panel de administración</p>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-sm text-stone-600">{usuario.nombre}</span>
            <button
              type="button"
              onClick={() => cerrarSesion()}
              className="rounded-md border border-stone-300 px-3 py-2 text-sm font-medium hover:bg-stone-100"
            >
              Cerrar sesión
            </button>
          </div>
        </div>
        <nav className="mx-auto flex max-w-5xl gap-2 px-6 pb-3">
          {/* end: sin esto, "Misiones" tambien se marcaria activo en /misiones/nueva,
              porque NavLink compara el comienzo de la direccion. */}
          <NavLink to="/misiones" end className={estiloEnlace}>
            Misiones
          </NavLink>
          <NavLink to="/misiones/nueva" className={estiloEnlace}>
            Nueva misión
          </NavLink>
        </nav>
      </header>
      <main className="mx-auto max-w-5xl px-6 py-8">
        <Outlet />
      </main>
    </div>
  )
}
