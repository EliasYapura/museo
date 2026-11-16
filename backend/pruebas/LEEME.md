# Pruebas

Son pruebas **de integración**: le hablan a la API por HTTP, como lo haría la
app, y van contra la base y el Storage de verdad. No hay dobles ni simulaciones.
Es a propósito: casi todo lo que había que verificar en este proyecto vive en el
límite entre la API y la base —qué escribe cada ruta, qué dispara un trigger,
qué decide el servidor y no el cliente—, y eso no se prueba simulando la base.

## Cómo correrlas

```bash
npm run dev     # en una terminal: la API en localhost:3000
npm test        # en otra
```

`npm test` corre todas y resume al final. Para correr una sola:

```bash
node --env-file=.env pruebas/probar-estadisticas.mjs
```

Hace falta el `.env` con `DATABASE_URL`, `JWT_SECRET` y las dos variables de
Supabase, y que en la base haya al menos un administrador activo y una sala.

Con `PRUEBAS_API` se apunta a otra dirección, por ejemplo la de Render. No es
buena idea: estas pruebas escriben.

## Qué cubre cada una

| Archivo | Historia | Qué comprueba |
| --- | --- | --- |
| `probar-dificultad.mjs` | ADM03 | La dificultad la calcula el servidor y se mantiene al día cuando cambian los desafíos |
| `probar-categorias.mjs` | ADM23 | Clasificar piezas, el filtro por categoría y los conteos |
| `probar-abm-categorias.mjs` | ADM23 | Crear, editar y borrar categorías; borrar una no borra sus piezas |
| `probar-seguridad.mjs` | SIS04 | El rol y el estado de la cuenta se leen de la base y no del token |
| `probar-limite-cuenta.mjs` | SIS04 | El límite de intentos cuenta por cuenta y no sólo por IP |
| `probar-icono.mjs` | ADM25 | La imagen de una insignia, el tipo decidido por el contenido |
| `probar-imagen-mision.mjs` | ADM25 | La portada de una misión; guardar el formulario no la borra |
| `probar-imagen-objeto.mjs` | ADM25 | La foto de una pieza; borrar la pieza borra su archivo |
| `probar-valoracion.mjs` | VIS14 | Una valoración por visitante; califica sólo quien terminó |
| `probar-consulta-valoraciones.mjs` | ADM26 | El promedio y el reparto de estrellas |
| `probar-estadisticas.mjs` | ADM22 | Participaciones, tiempo mediano y fallos por desafío |

## Las tres reglas que siguen todas

**Cada prueba arma sus datos y los borra.** No dependen del contenido que haya
cargado, ni unas de otras, ni del orden. Si una falla a mitad de camino, el
`finally` limpia igual.

**Se borra por id, nunca por un patrón.** Con un `LIKE '%@prueba.test'`, una
cuenta que entre después por casualidad se borraría sin que nadie la haya visto.
Lo mismo con los eventos de la bitácora.

**El token se firma en la prueba**, con el secreto del `.env`, en lugar de
entrar con usuario y contraseña. Así no hacen falta credenciales de nadie para
correrlas, y de paso no gastan la cuota de intentos de login.

## Dos cosas que costaron y conviene no volver a romper

**El límite de intentos es por cliente y vive en memoria.** Dos de estas
pruebas lo gastan a propósito. Para no dejarse sin login unas a otras —ni
bloquear por quince minutos a quien está programando— cada una se presenta con
una IP inventada propia en `X-Forwarded-For`, del rango 198.18.0.0/15. La API
le cree porque corre con `trust proxy = 1`, que es lo que necesita detrás de
Render. Esto es lo que hace que la suite se pueda correr dos veces seguidas.

**Que un archivo siga bajándose no prueba que esté.** Storage sirve las URLs
públicas por una caché de borde que responde un rato después de borrar el
archivo. Por eso, cuando hay que verificar que una imagen se borró, se mira la
lista del bucket y no la URL.
