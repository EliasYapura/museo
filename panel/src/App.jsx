// Pantalla base del panel. En ADM01 se reemplaza por el ruteo con login.
export default function App() {
  return (
    <div className="min-h-screen bg-stone-50 text-stone-900">
      <header className="border-b border-stone-200 bg-white">
        <div className="mx-auto max-w-5xl px-6 py-4">
          <p className="text-sm text-stone-500">Exploradores del Museo</p>
          <h1 className="text-xl font-semibold">Panel de administración</h1>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-6 py-10">
        <p className="text-stone-600">El panel está listo para empezar a cargar contenido.</p>
      </main>
    </div>
  )
}
