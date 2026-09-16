import { useCallback, useMemo, useState } from 'react'
import { pedir } from '../api.js'
import { SesionContext } from './contexto.js'

// sessionStorage se borra al cerrar la pestana, a diferencia de localStorage.
// Las computadoras del personal de un museo suelen ser compartidas: asi,
// cerrar el navegador equivale a cerrar la sesion.
const CLAVE = 'sesion'

// Lee el vencimiento que la API pone dentro del token. No verifica la firma:
// eso solo lo puede hacer la API, que es quien conoce el secreto. Sirve para
// no mostrar el panel con una sesion que la API ya va a rechazar.
function vencido(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    const { exp } = JSON.parse(atob(base64))
    return Date.now() >= exp * 1000
  } catch {
    return true
  }
}

function leerSesionGuardada() {
  try {
    const sesion = JSON.parse(sessionStorage.getItem(CLAVE))
    if (sesion?.token && !vencido(sesion.token)) return sesion
  } catch {
    // Dato corrupto o almacenamiento bloqueado: se arranca sin sesion.
  }
  sessionStorage.removeItem(CLAVE)
  return null
}

export function SesionProvider({ children }) {
  const [sesion, setSesion] = useState(leerSesionGuardada)
  // Motivo por el que se cerro la sesion, para explicarlo en el login.
  const [aviso, setAviso] = useState('')

  const iniciarSesion = useCallback(async (email, password) => {
    const { token, usuario } = await pedir('/auth/login', {
      metodo: 'POST',
      cuerpo: { email, password },
    })

    // Este control es solo para la experiencia de uso. La proteccion real es
    // el 403 de la API: el codigo del panel corre en el navegador y cualquiera
    // puede modificarlo.
    if (usuario.rol !== 'administrador') {
      throw new Error('Esta cuenta no tiene permisos de administrador')
    }

    const nueva = { token, usuario }
    sessionStorage.setItem(CLAVE, JSON.stringify(nueva))
    setAviso('')
    setSesion(nueva)
  }, [])

  // El aviso viaja en la sesion y no en la navegacion: al borrar la sesion,
  // RutaProtegida redirige al login por su cuenta, y cualquier otra
  // redireccion hecha al mismo tiempo quedaria pisada, perdiendo el mensaje.
  const cerrarSesion = useCallback((motivo = '') => {
    sessionStorage.removeItem(CLAVE)
    setAviso(motivo)
    setSesion(null)
  }, [])

  const valor = useMemo(
    () => ({ token: sesion?.token, usuario: sesion?.usuario, aviso, iniciarSesion, cerrarSesion }),
    [sesion, aviso, iniciarSesion, cerrarSesion],
  )

  return <SesionContext.Provider value={valor}>{children}</SesionContext.Provider>
}
