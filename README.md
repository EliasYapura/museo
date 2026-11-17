# Exploradores del Museo

App de gamificación educativa para museos. Los visitantes recorren las salas,
escanean códigos QR junto a las piezas y resuelven desafíos para sumar puntos
e insignias. La misma app incluye la administración, donde el personal del
museo carga el contenido y consulta las estadísticas de uso sin programar.

La aplicación es **genérica**: no está atada a la temática de ninguna
institución en particular. El Museo de La Plata se usa únicamente como caso
de ejemplo para poblar los datos de prueba.

Proyecto de la materia **Laboratorio de Desarrollo de Software** (UNPA-UACO).

## Stack

| Componente | Tecnología |
|---|---|
| App del visitante y administración | Flutter (Dart) |
| API | Node.js + Express |
| Base de datos | PostgreSQL (Supabase) |
| Archivos | Supabase Storage |
| Autenticación | JWT + bcrypt |
| Despliegue | Render (API) · APK en los releases |

## Estructura

```
museo/
├── app/          App Flutter: el recorrido del visitante y la administración
├── backend/      API REST en Node + Express, con sus pruebas
└── docs/         Esquema de base de datos, DER, backlog y plan de pruebas
    └── der/      Genera el diagrama entidad-relación desde schema.sql
```

## Requisitos

- Flutter 3.x y el SDK de Android
- Node.js 22.9 o superior
- Una cuenta de Supabase con un proyecto PostgreSQL

## Cómo levantar el proyecto

### Base de datos

Ejecutar en el editor SQL de Supabase, en este orden:

1. `docs/schema.sql` — crea las 13 tablas, los tipos, el trigger y la vista
2. `docs/seed.sql` — carga datos de ejemplo

### API

```bash
cd backend
cp .env.example .env    # completar los valores
npm install
npm run dev
```

Queda escuchando en `http://localhost:3000`. Para verificar que está viva:

```bash
curl http://localhost:3000/health
```

#### Pruebas

```bash
npm test
```

Corre las once pruebas de `backend/pruebas/` y resume al final. Necesitan la API
levantada en otra terminal y el `.env` completo: le hablan a la API por HTTP y
van contra la base de verdad. Cada una arma sus datos y los borra al terminar.

El detalle de qué cubre cada una, y las dos trampas que hay que conocer antes de
tocarlas, está en [`backend/pruebas/LEEME.md`](backend/pruebas/LEEME.md).

#### Endpoints

Las rutas con token esperan el header `Authorization: Bearer <token>`.

**Salud y cuentas**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/health` | público | Estado de la API. No consulta la base, así que responde aunque la base esté caída |
| POST | `/auth/registro` | público | Crea una cuenta de visitante. Máximo 5 por hora y por IP |
| POST | `/auth/login` | público | Devuelve un JWT válido por 8 horas. Máximo 10 intentos fallidos por cuenta cada 15 minutos |
| GET | `/auth/perfil` | con token | Datos del usuario autenticado |

**Lo que consume la app del visitante**

Ninguna pide token, pero si llega uno válido se aprovecha: es lo que distingue
al visitante con cuenta, al que se le guarda el progreso, del que recorre sin
cuenta. La única excepción es la valoración, que sí exige cuenta.

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/publico/misiones` | público | Las misiones publicadas: sin respuestas correctas ni datos de administración |
| GET | `/publico/misiones/:id` | público | El detalle, con las salas del recorrido; 404 si está en borrador o archivada |
| GET | `/publico/misiones/:id/desafios` | público | Los desafíos a jugar, en orden. Con sesión, trae el progreso guardado |
| POST | `/publico/desafios/:id/escaneo` | público | Compara el código escaneado con la pieza del desafío. Devuelve el dato clave y la foto sólo si acertó |
| POST | `/publico/desafios/:id/respuesta` | público | Comprueba la respuesta y otorga los puntos, con el descuento de las pistas ya aplicado |
| GET | `/publico/desafios/:id/pista` | público | La pista que sigue, con su penalización. Con sesión, cuáles se usaron sale del progreso y no del pedido |
| POST | `/publico/misiones/:id/completada` | público | Deja constancia del final y devuelve las insignias recién ganadas |
| POST | `/publico/misiones/:id/valoracion` | **con token** | Califica la misión de 1 a 5. Exige haberla terminado; una valoración por visitante |
| GET | `/publico/insignias` | público | El catálogo de insignias. Con token, cada una dice si ya se ganó |

**Misiones**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/misiones` | administrador | Las misiones no archivadas, con sus desafíos, valoraciones y promedio |
| POST | `/misiones` | administrador | Crea una misión, siempre en borrador. La dificultad la calcula el servidor |
| GET | `/misiones/:id` | administrador | Datos de una misión, con el reparto de sus valoraciones |
| PUT | `/misiones/:id` | administrador | Modifica nombre, descripción y duración. No toca la portada ni la publicación |
| POST | `/misiones/:id/imagen` | administrador | Sube la portada. El cuerpo son los bytes de la imagen, con su `Content-Type` |
| DELETE | `/misiones/:id/imagen` | administrador | Le saca la portada y borra el archivo |
| PATCH | `/misiones/:id/activa` | administrador | Publica (`{ "activa": true }`) o despublica; 409 si no tiene desafíos |
| PATCH | `/misiones/:id/archivada` | administrador | Archiva o devuelve al listado. Archivar también despublica |

**Desafíos y pistas**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/misiones/:id/desafios` | administrador | Los desafíos de una misión, en orden |
| POST | `/misiones/:id/desafios` | administrador | Agrega un desafío al final, con los datos de su tipo |
| PUT | `/misiones/:id/desafios/orden` | administrador | Reordena: recibe la lista completa de ids y los renumera |
| GET | `/desafios/:id` | administrador | Datos de un desafío |
| PUT | `/desafios/:id` | administrador | Modifica enunciado, tipo, objeto, puntos y respuesta correcta |
| DELETE | `/desafios/:id` | administrador | Borra un desafío y sus pistas; si era el último, despublica la misión |
| GET | `/desafios/:id/pistas` | administrador | Las pistas del desafío, en orden |
| POST | `/desafios/:id/pistas` | administrador | Agrega una pista al final |
| PUT | `/pistas/:id` | administrador | Cambia el texto y la penalización |
| DELETE | `/pistas/:id` | administrador | Borra una pista |

**Piezas del museo**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/objetos` | administrador | Las piezas, activas y dadas de baja, con su sala, su categoría y en cuántos desafíos se usan. `?categoria=<id>` o `?categoria=sin` filtra |
| POST | `/objetos` | administrador | Registra una pieza y le genera un código único |
| GET | `/objetos/:id` | administrador | Datos de una pieza |
| GET | `/objetos/:id/desafios` | administrador | Los desafíos que la usan, con su misión |
| PUT | `/objetos/:id` | administrador | Modifica nombre, sala, categoría, dato clave, descripción e identificador. No toca la foto ni el código |
| POST | `/objetos/:id/imagen` | administrador | Sube la foto de la pieza |
| DELETE | `/objetos/:id/imagen` | administrador | Le saca la foto y borra el archivo |
| PATCH | `/objetos/:id/codigo` | administrador | Genera un código nuevo. Deja inservible la etiqueta ya impresa |
| PATCH | `/objetos/:id/estado` | administrador | Da de baja o reactiva |
| DELETE | `/objetos/:id` | administrador | Borra la pieza y su foto; 409 si algún desafío la usa |
| GET | `/salas` | administrador | Las salas, en el orden del recorrido |
| GET | `/categorias` | administrador | Las categorías, con cuántas piezas tiene cada una y cuántas quedaron sin clasificar |
| POST | `/categorias` | administrador | Crea una categoría |
| PUT | `/categorias/:id` | administrador | Le cambia el nombre |
| DELETE | `/categorias/:id` | administrador | La borra. Sus piezas no se borran: quedan sin clasificar |

**Insignias**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/insignias` | administrador | Todas, con a cuántos visitantes se les otorgó |
| POST | `/insignias` | administrador | Crea una insignia. Nace sin condición, así que todavía nadie puede ganarla |
| GET | `/insignias/:id` | administrador | Datos de una insignia |
| PUT | `/insignias/:id` | administrador | Modifica nombre y descripción. No toca la condición, el ícono ni si está activa |
| PUT | `/insignias/:id/condicion` | administrador | Define cómo se gana |
| PATCH | `/insignias/:id/activa` | administrador | Deja de otorgarla sin quitársela a quien ya la tiene |
| POST | `/insignias/:id/icono` | administrador | Sube la imagen |
| DELETE | `/insignias/:id/icono` | administrador | Le saca la imagen y borra el archivo |
| DELETE | `/insignias/:id` | administrador | La borra. **Se la quita a todos los visitantes que la ganaron**, y la respuesta dice a cuántos |

**Estadísticas de uso**

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/estadisticas` | administrador | El resumen del museo y una fila por misión: participaciones, completadas, tiempo mediano, pistas y fallos |
| GET | `/estadisticas/misiones/:id` | administrador | El detalle de una misión, desafío por desafío |

Las participaciones se cuentan desde la bitácora de eventos, que registra
también a los visitantes sin cuenta. Los tiempos salen del progreso guardado,
que existe sólo con cuenta, así que siempre son menos: la respuesta dice sobre
cuántos recorridos se calculó.

Las tres rutas que suben imágenes reciben los bytes crudos y no un formulario
multipart, con `Content-Type: image/png`, `image/jpeg` o `image/webp`. Ese tipo
no decide nada: el servidor reconoce la imagen por sus primeros bytes y rechaza
lo que no sea una de las tres, diga lo que diga el cliente.

El registro siempre crea visitantes. Para dar de alta un administrador, se
registra la cuenta y se la promueve en la base:

```sql
UPDATE usuarios SET rol = 'administrador' WHERE email = 'persona@museo.org';
```

### App del visitante

```bash
cd app
flutter pub get
flutter run
```

Necesita la API levantada. La dirección de la API se resuelve sola según dónde
corra la app, así que no hay que editar código para cambiar de forma de probar:

| Dónde se prueba | Dirección que usa | Cómo se corre |
| --- | --- | --- |
| Navegador | `http://localhost:3000` | `flutter run -d edge --web-port=5000` |
| Emulador de Android | `http://10.0.2.2:3000` | `flutter run` con el emulador abierto |
| Teléfono por USB | la que se le pase | `flutter run --dart-define=API_URL=http://<IP-de-la-PC>:3000` |

`10.0.2.2` es la dirección con la que el emulador llega a la computadora que lo
hospeda: dentro del emulador, `localhost` es el propio teléfono virtual.

En el navegador hace falta además que la API autorice ese origen: es la
variable `APP_ORIGIN` del backend, que por defecto vale `http://localhost:5000`.
Por eso el `--web-port=5000`.

## Despliegue

| Qué | Dónde |
| --- | --- |
| API | https://exploradores-museo-api.onrender.com |
| Base de datos | Supabase, proyecto `exploradores-museo` |
| App | el APK de cada entrega, en los [releases](https://github.com/EliasYapura/museo/releases) |

La API se publica en Render y la base ya está en Supabase.

**El deploy de la API no es automático.** Subir a `main` no lo dispara: el
servicio se creó desde la dirección pública del repositorio, y así Render no
instala el webhook de GitHub. Después de cada `push` hay que entrar al panel de
Render y usar *Manual Deploy*. En el panel la opción de despliegue automático
aparece activada, que es lo que confunde.

El panel web de administración, que estaba en Vercel, dejó de usarse en el
Sprint 5: la administración se hizo dentro de la app. El código quedó en
`panel/` hasta el Sprint 7, cuando se retiró del repositorio.

### API en Render

La configuración está en [`render.yaml`](render.yaml). Las variables marcadas
`sync: false` se cargan desde el panel de Render y nunca se versionan:

| Variable | Valor |
| --- | --- |
| `DATABASE_URL` | la cadena de conexión de Supabase (Session pooler) |
| `JWT_SECRET` | uno nuevo, distinto al de desarrollo, de 32 caracteres o más |
| `APP_ORIGIN` | `http://localhost:5000`, para probar la app en el navegador |
| `SUPABASE_URL` | la dirección del proyecto, sin barra final |
| `SUPABASE_SERVICE_KEY` | la *Secret key*, que saltea RLS y vive sólo en el servidor |

Para generar un secreto nuevo:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

El secreto de producción tiene que ser distinto al de desarrollo: si se
filtrara el del repositorio local, cualquiera podría fabricar tokens de
administrador contra el servidor publicado.

### Imágenes en Supabase Storage

Las imágenes de insignias, portadas de misiones y fotos de piezas se guardan en
tres buckets públicos, uno por tabla: `insignias`, `misiones` y `objetos`. Los
tres con un tope de 2 MB por archivo y limitados a PNG, JPEG y WebP.

El archivo no viaja de la app a Supabase: va de la app a la API, y de ahí a
Storage con la clave de servicio. Si la app subiera sola, esa clave tendría que
estar dentro del APK, y cualquiera que lo abra la tiene.

### App del visitante

No se despliega: es una app, no una página. Se compila apuntando a la API:

```bash
flutter build apk --dart-define=API_URL=https://<api-en-render>
```

### Dos cosas del plan gratuito

- **Render apaga el servicio** tras unos minutos sin pedidos. El siguiente
  tarda cerca de un minuto en responder, por eso la app espera 60 segundos
  antes de dar por perdida la conexión.
- **Supabase pausa el proyecto** tras varios días sin uso. Si falla con
  `tenant or user not found`, hay que restaurarlo desde el panel de Supabase.

## Convenciones del repositorio

Cada commit lleva al principio el código de la historia de usuario que
implementa:

```
ADM01: agrego endpoint POST /misiones con validación de rol
```

El trabajo técnico que no corresponde a una historia de usuario usa el
prefijo `TEC`:

```
TEC02: adapto esquema para que sea independiente de la temática del museo
```

Una historia se considera terminada cuando cumple **todos** sus criterios de
aceptación y fue probada manualmente.
