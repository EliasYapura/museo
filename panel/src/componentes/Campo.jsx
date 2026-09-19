// Etiqueta, ayuda y mensaje de error de un campo de formulario. El error se
// vincula al campo con aria-describedby, para que un lector de pantalla lo
// anuncie. Lo comparten los formularios de misiones y de objetos.
export default function Campo({ id, etiqueta, obligatorio, opcional, ayuda, error, children }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-sm font-medium">
        {etiqueta}
        {obligatorio && (
          <span aria-hidden="true" className="ml-0.5 text-red-600">
            *
          </span>
        )}
        {opcional && <span className="font-normal text-stone-500"> (opcional)</span>}
      </label>
      {children}
      {ayuda && (
        <p id={`${id}-ayuda`} className="mt-1 text-sm text-stone-500">
          {ayuda}
        </p>
      )}
      {error && (
        <p id={`${id}-error`} className="mt-1 text-sm font-medium text-red-700">
          {error}
        </p>
      )}
    </div>
  )
}
