const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

// Error con el codigo HTTP adjunto, para que las pantallas puedan distinguir
// "sesion vencida" (401) de "sin permiso" (403) o "datos invalidos" (400).
export class ErrorApi extends Error {
  constructor(status, mensaje) {
    super(mensaje)
    this.status = status
  }
}

export async function pedir(ruta, { metodo = 'GET', cuerpo, token } = {}) {
  const headers = {}
  if (cuerpo !== undefined) headers['Content-Type'] = 'application/json'
  if (token) headers.Authorization = `Bearer ${token}`

  let respuesta
  try {
    respuesta = await fetch(API_URL + ruta, {
      method: metodo,
      headers,
      body: cuerpo !== undefined ? JSON.stringify(cuerpo) : undefined,
    })
  } catch {
    // fetch solo falla asi cuando no hubo respuesta: API apagada, sin red o
    // bloqueo de CORS. Se usa el codigo 0 porque no existe un codigo HTTP.
    throw new ErrorApi(0, 'No se pudo conectar con el servidor')
  }

  const datos = await respuesta.json().catch(() => null)
  if (!respuesta.ok) {
    throw new ErrorApi(respuesta.status, datos?.error ?? 'Ocurrió un error inesperado')
  }
  return datos
}
