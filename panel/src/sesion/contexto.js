import { createContext, useContext } from 'react'

// El contexto y el hook viven separados del componente SesionProvider porque
// la recarga en caliente de Vite (Fast Refresh) solo funciona bien cuando un
// archivo .jsx exporta unicamente componentes.
export const SesionContext = createContext(null)

export function useSesion() {
  return useContext(SesionContext)
}
