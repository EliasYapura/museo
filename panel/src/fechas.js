// La API devuelve fechas en UTC (formato ISO). Se muestran en la zona horaria
// del navegador, que para el personal del museo es la hora local.
const formato = new Intl.DateTimeFormat('es-AR', { dateStyle: 'short', timeStyle: 'short' })

export const formatearFecha = (iso) => formato.format(new Date(iso))
