# Exploradores del Museo

App de gamificación educativa para museos. Los visitantes recorren las salas,
escanean códigos QR junto a las piezas y resuelven desafíos para sumar puntos
e insignias. Incluye un panel web donde el personal del museo carga el
contenido sin programar.

La aplicación es **genérica**: no está atada a la temática de ninguna
institución en particular. El Museo de La Plata se usa únicamente como caso
de ejemplo para poblar los datos de prueba.

Proyecto de la materia **Laboratorio de Desarrollo de Software** (UNPA-UACO).

## Stack

| Componente | Tecnología |
|---|---|
| App del visitante | Flutter (Dart) |
| Panel de administración | React + Tailwind CSS |
| API | Node.js + Express |
| Base de datos | PostgreSQL (Supabase) |
| Autenticación | JWT + bcrypt |
| Despliegue | Vercel (panel) · Render (API) |

## Estructura

```
museo/
├── app/          App Flutter del visitante
├── backend/      API REST en Node + Express
├── docs/         Esquema de base de datos, DER, backlog y plan de pruebas
└── panel/        Panel de administración en React + Vite + Tailwind
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

#### Endpoints

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| GET | `/health` | público | Estado de la API |
| POST | `/auth/registro` | público | Crea una cuenta de visitante |
| POST | `/auth/login` | público | Devuelve un JWT válido por 8 horas |
| GET | `/auth/perfil` | con token | Datos del usuario autenticado |

Las rutas con token esperan el header `Authorization: Bearer <token>`.

El registro siempre crea visitantes. Para dar de alta un administrador, se
registra la cuenta y se la promueve en la base:

```sql
UPDATE usuarios SET rol = 'administrador' WHERE email = 'persona@museo.org';
```

### Panel de administración

```bash
cd panel
cp .env.example .env    # dirección de la API
npm install
npm run dev
```

Queda disponible en `http://localhost:5173`. Necesita la API levantada.

### App del visitante

```bash
cd app
flutter pub get
flutter run
```

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
