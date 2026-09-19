import { useEffect, useState } from 'react'
import QRCode from 'qrcode'

// Bloque del identificador de un objeto (ADM17): muestra su codigo y, si la
// pieza se identifica con QR, el codigo QR listo para descargar e imprimir.
//
// El QR contiene el codigo tal cual (OBJ-XXXXXXXX), que es lo que la app va a
// comparar contra el objeto al escanear (SIS01). No lleva una direccion web
// porque no depende de ningun dominio.
//
// Props:
// - objeto: el objeto con codigo y tipo_identificador.
// - alRegenerar(): pide a la API un codigo nuevo. Si falla, lanza el error.

const MEDIDA_QR = 512 // pixeles del PNG que se descarga, para que imprima nitido

export default function IdentificadorObjeto({ objeto, alRegenerar }) {
  const [imagenQr, setImagenQr] = useState('')
  const [errorQr, setErrorQr] = useState('')
  const [confirmando, setConfirmando] = useState(false)
  const [regenerando, setRegenerando] = useState(false)
  const [error, setError] = useState('')

  const esQr = objeto.tipo_identificador === 'qr'

  useEffect(() => {
    if (!esQr) return
    let vigente = true
    QRCode.toDataURL(objeto.codigo, { width: MEDIDA_QR, margin: 2 })
      .then((url) => vigente && setImagenQr(url))
      .catch(() => vigente && setErrorQr('No se pudo dibujar el código QR.'))
    return () => {
      vigente = false
    }
  }, [objeto.codigo, esQr])

  async function regenerar() {
    setError('')
    setRegenerando(true)
    try {
      await alRegenerar()
      setConfirmando(false)
    } catch (err) {
      setError(err.message)
    } finally {
      setRegenerando(false)
    }
  }

  return (
    <section className="mb-6 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold">
        {esQr ? 'Código QR de la pieza' : 'Etiqueta NFC de la pieza'}
      </h2>

      {/* etiqueta-imprimible: lo unico que sale al imprimir (ver index.css). */}
      <div className="etiqueta-imprimible mt-4 flex flex-wrap items-center gap-6">
        {esQr && imagenQr && (
          <img
            src={imagenQr}
            alt={`Código QR de ${objeto.nombre}`}
            className="size-44 rounded-md border border-stone-200"
          />
        )}
        <div>
          <p className="font-medium">{objeto.nombre}</p>
          <p className="font-mono text-lg">{objeto.codigo}</p>
        </div>
      </div>

      {errorQr && (
        <p role="alert" className="mt-3 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {errorQr}
        </p>
      )}

      <p className="mt-4 text-sm text-stone-600">
        {esQr
          ? 'Imprimí esta etiqueta y pegala junto a la pieza. El QR contiene el código, que es lo que la app compara al escanear.'
          : 'Grabá este código en la etiqueta NFC con una app del celular, apoyándolo sobre la etiqueta: una página web no puede escribir un chip NFC.'}
      </p>

      <div className="mt-4 flex flex-wrap gap-2">
        {esQr && imagenQr && (
          <>
            <a
              href={imagenQr}
              download={`${objeto.codigo}.png`}
              className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium text-stone-900 hover:bg-stone-100"
            >
              Descargar imagen
            </a>
            <button
              type="button"
              onClick={() => window.print()}
              className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
            >
              Imprimir etiqueta
            </button>
          </>
        )}
        {!confirmando && (
          <button
            type="button"
            onClick={() => {
              setError('')
              setConfirmando(true)
            }}
            className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-stone-100"
          >
            Generar un código nuevo
          </button>
        )}
      </div>

      {/* La confirmacion es parte de la pantalla y no un cartel del navegador:
          asi se explica la consecuencia, que no es obvia. */}
      {confirmando && (
        <div role="alert" className="mt-4 rounded-md border border-amber-200 bg-amber-50 p-4">
          <p className="text-sm text-amber-900">
            Si generás un código nuevo, la etiqueta que ya está puesta junto a la pieza deja de
            funcionar y hay que reemplazarla. ¿Querés generarlo igual?
          </p>
          <div className="mt-3 flex gap-2">
            <button
              type="button"
              onClick={regenerar}
              disabled={regenerando}
              className="rounded-md bg-stone-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-60"
            >
              {regenerando ? 'Generando…' : 'Sí, generar uno nuevo'}
            </button>
            <button
              type="button"
              onClick={() => setConfirmando(false)}
              disabled={regenerando}
              className="rounded-md border border-stone-300 px-3 py-1.5 text-sm font-medium hover:bg-white disabled:opacity-60"
            >
              Cancelar
            </button>
          </div>
        </div>
      )}

      {error && (
        <p role="alert" className="mt-3 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}
    </section>
  )
}
