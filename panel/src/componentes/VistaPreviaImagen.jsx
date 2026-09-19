import { useState } from 'react'

// Muestra en chico la imagen guardada de un objeto (ADM16), para que el
// administrador confirme que la direccion carga la foto correcta. Si la
// imagen no carga (direccion rota, sitio caido, no es una imagen), lo avisa.
//
// Quien lo usa le pone key={url}: asi, al guardar una direccion nueva, el
// componente arranca de cero y no arrastra el error de la anterior.
export default function VistaPreviaImagen({ url, descripcion }) {
  const [fallo, setFallo] = useState(false)

  if (fallo) {
    return (
      <p role="status" className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
        No se pudo cargar la imagen guardada. Revisá que la dirección sea correcta y que apunte a una imagen.
      </p>
    )
  }

  return (
    <figure className="w-fit">
      <img
        src={url}
        alt={descripcion}
        onError={() => setFallo(true)}
        className="max-h-48 max-w-full rounded-md border border-stone-200 bg-white object-contain"
      />
      <figcaption className="mt-1 text-sm text-stone-500">Imagen guardada</figcaption>
    </figure>
  )
}
