# Diagrama entidad-relación

```bash
node docs/der/armar-der.mjs
```

Escribe `docs/Relaciones_Base_de_Datos.pdf` y `.svg`. **Hay que correrlo cada
vez que cambie el esquema.**

## Por qué se genera

El diagrama anterior era una imagen hecha aparte y pegada en un PDF. No tenía
forma de saber que había quedado viejo, y quedó: mostraba la tabla
`recompensas`, de una historia que se descartó, y no mostraba `valoraciones`.

Este sale de `docs/schema.sql`, que es la única fuente de verdad del esquema.
Si una tabla no está ahí, no se dibuja; si está, se dibuja con todas sus
columnas y sus claves. No se puede desincronizar sin que alguien borre la
tabla del esquema.

Al terminar, el propio generador abre el PDF que acaba de escribir y comprueba
que estén los nombres de las trece tablas y de todas sus columnas. Eso se puede
hacer porque el texto va como texto y no como dibujo, que es lo que no se podía
con la imagen.

## Las piezas

| Archivo | Qué hace |
| --- | --- |
| `leer-esquema.mjs` | Lee `schema.sql` y devuelve tablas, columnas y relaciones. Corriéndolo suelto imprime lo que entendió, que es como se revisa |
| `pdf.mjs` | Lo mínimo de PDF: rectángulos, líneas, texto. Sin bibliotecas |
| `svg.mjs` | Lo mismo en SVG, con los mismos métodos |
| `armar-der.mjs` | La distribución, los colores y el dibujo |

No necesita instalar nada: se corre con `node` pelado.

## Dos decisiones del dibujo

**Las líneas no cruzan las cajas.** Van por los pasillos verticales que quedan
entre columna y columna, y las que unen tablas lejanas bajan a una banda abajo
de todo. Una línea recta entre dos tablas separadas pasaría por detrás de las
cajas del medio y la relación desaparecería del dibujo, que es peor que un
camino largo.

**Las tablas están agrupadas por familia y no alfabéticamente**, con un color
por grupo. Las que se usan juntas quedan cerca, y así la mayoría de las flechas
va entre columnas vecinas.

## Si hay que mover algo

La distribución está en la constante `COLUMNAS` de `armar-der.mjs`: una lista
por columna, de izquierda a derecha. El generador corta con un error si una
tabla del esquema no está en ninguna columna, así que agregar una tabla nueva
no se puede olvidar.
