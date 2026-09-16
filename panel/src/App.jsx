import { BrowserRouter, Navigate, Route, Routes } from 'react-router'
import Marco from './componentes/Marco.jsx'
import RutaProtegida from './componentes/RutaProtegida.jsx'
import EditarMision from './paginas/EditarMision.jsx'
import ListaMisiones from './paginas/ListaMisiones.jsx'
import Login from './paginas/Login.jsx'
import NuevaMision from './paginas/NuevaMision.jsx'
import { SesionProvider } from './sesion/SesionProvider.jsx'

export default function App() {
  return (
    <BrowserRouter>
      <SesionProvider>
        <Routes>
          <Route path="/login" element={<Login />} />

          {/* Todo lo que esta aca adentro exige sesion de administrador. */}
          <Route element={<RutaProtegida />}>
            <Route element={<Marco />}>
              <Route path="/misiones" element={<ListaMisiones />} />
              <Route path="/misiones/nueva" element={<NuevaMision />} />
              <Route path="/misiones/:id/editar" element={<EditarMision />} />
            </Route>
          </Route>

          <Route path="*" element={<Navigate to="/misiones" replace />} />
        </Routes>
      </SesionProvider>
    </BrowserRouter>
  )
}
