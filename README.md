# ⚽ Liga Barrial · Torneo eliminatorio

Aplicación para administrar un torneo de fútbol barrial por eliminación directa: equipos, jugadores, sedes, árbitros y partidos de la llave (cuartos → semifinales → final).

Entrega Final del Proyecto Integrador · Bases de Datos · Universidad Pontificia Bolivariana.

## Integrantes

- Santiago Garcia
- Sofía Henao
- Alejandro Restrepo
- David Aguirre Bustamante

## Tecnologías

| Capa | Tecnología | Carpeta |
|---|---|---|
| Base de datos | PostgreSQL | `db/` |
| API | Python · FastAPI + psycopg2 | `api/` |
| Aplicación | HTML + CSS + JavaScript (fetch) | `app/` |

La aplicación solo habla con la API por HTTP. La API es el único programa que se conecta a la base.

## Estructura del repositorio

```
liga-barrial/
├── db/
│   ├── ddl.sql                 Tablas, restricciones, índices, funciones, triggers y vista
│   └── datos.sql               Datos de ejemplo del caso
├── api/
│   ├── main.py                 Crea la API, configura CORS y registra las rutas
│   ├── database.py             Conexión (lee el .env) y manejo de errores con rollback
│   ├── modelos.py              Forma del cuerpo de cada solicitud (validación → 422)
│   ├── rutas/                  Endpoints: equipos, jugadores, sedes y árbitros, partidos, consultas
│   ├── requirements.txt
│   └── .env.example            Variables que necesita la API (sin valores reales)
├── app/
│   ├── index.html
│   ├── css/estilos.css
│   └── js/                     config.js (URL de la API), api.js, crud.js, consultas.js, main.js
└── docs/
    ├── diagrama_er.md          Diagrama E-R final
    └── diccionario_de_datos.md
```

## Cómo levantar todo desde cero

Requisitos: PostgreSQL, Python 3.10 o superior y un navegador.

### 1. Crear la base

En pgAdmin (Query Tool) o en psql:

```sql
CREATE DATABASE liga_barrial;
```

Conectarse a `liga_barrial` y correr, en este orden:

```bash
psql -U postgres -d liga_barrial -f db/ddl.sql
psql -U postgres -d liga_barrial -f db/datos.sql
```

En pgAdmin: abrir cada archivo con **Open File** en el Query Tool de `liga_barrial` y ejecutarlo con **F5**.

### 2. Configurar el .env

```bash
cd api
copy .env.example .env        # en Mac/Linux: cp .env.example .env
```

Abrir `api/.env` y poner la contraseña real de PostgreSQL en `DB_PASSWORD`. El `.env` no se sube al repositorio.

### 3. Correr la API

```bash
cd api
python -m venv venv
venv\Scripts\activate          # en Mac/Linux: source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

La API queda en http://127.0.0.1:8000 y la documentación Swagger en **http://127.0.0.1:8000/docs**.

### 4. Correr la aplicación

En otra terminal:

```bash
cd app
python -m http.server 5500
```

Abrir **http://localhost:5500** en el navegador. El puerto 5500 ya está permitido en el CORS de la API.
Si la API corre en otra dirección, se cambia en `app/js/config.js`.

### Atajo: prender todo desde Visual Studio Code

Al abrir la carpeta `liga-barrial` en VS Code, la tarea **Prender Liga Barrial** (`.vscode/tasks.json`) arranca la API y la app en dos terminales.
Si no arranca sola: **Terminal → Ejecutar tarea… → Prender Liga Barrial**. En Windows también se puede usar `iniciar.bat`.

## Endpoints de la API

| Recurso | Endpoints |
|---|---|
| Equipos | `GET /equipos` (`?barrio=`), `GET /equipos/{id}`, `POST /equipos`, `PUT /equipos/{id}`, `DELETE /equipos/{id}` |
| Jugadores (FK → equipos) | `GET /jugadores` (`?id_equipo=&estado=`), `GET /jugadores/{id}`, `POST`, `PUT /jugadores/{id}`, `DELETE /jugadores/{id}` |
| Sedes | `GET /sedes`, `GET /sedes/{id}`, `POST`, `PUT /sedes/{id}`, `DELETE /sedes/{id}` |
| Árbitros | `GET /arbitros`, `GET /arbitros/{id}`, `POST`, `PUT /arbitros/{id}`, `DELETE /arbitros/{id}` |
| Partidos (FK → sede, árbitro, partido) | `GET /partidos` (`?fase=`), `GET /partidos/{id}`, `POST`, `PUT /partidos/{id}`, `DELETE /partidos/{id}` |

### Consultas de negocio (JOIN / GROUP BY)

| Endpoint | Pregunta que responde |
|---|---|
| `GET /consultas/jugadores-activos-por-equipo` | ¿Cuántos jugadores habilitados tiene cada equipo? |
| `GET /consultas/partidos-por-arbitro` | ¿Cuántos partidos ya jugados ha dirigido cada árbitro? |
| `GET /consultas/partidos-por-sede?desde=` | ¿Cuántos partidos se juegan en cada sede desde una fecha? |
| `GET /consultas/llave` | Camino de cada partido de cuartos hasta la final (self-join) |
| `GET /consultas/resumen-equipos` | Resumen por equipo (vista `vista_resumen_equipos`) |

### Lógica del motor en uso

| Endpoint | Qué usa de PostgreSQL | Dónde se ve en la aplicación |
|---|---|---|
| `GET /equipos/{id}/plantilla` | Función `obtener_estado_plantilla` | Equipos → botón **Plantilla** |
| `POST /equipos/{id}/rehabilitar` | Función `rehabilitar_jugadores_equipo` | Equipos → botón **Rehabilitar** |
| `POST /partidos/{id}/equipos` | Función `asignar_equipos_partido` + trigger `trg_validar_max_equipos_partido` | Partidos → **Asignar equipos** |
| `POST` / `PUT /partidos` | Trigger `trg_validar_disponibilidad_arbitro` | Partidos → crear o editar con un árbitro ocupado |
| `PUT /jugadores/{id}` | Trigger `trg_validar_estado_jugador` | Jugadores → editar |

### Errores

| Código | Cuándo | Ejemplo en la aplicación |
|---|---|---|
| 404 | El registro no existe | "No existe un equipo con ID 99." |
| 409 | La base rechaza el dato (llave foránea, UNIQUE, CHECK o una regla de un trigger o función) | "Ese equipo tiene jugadores registrados, no se puede borrar." |
| 422 | El cuerpo no tiene la forma esperada | "El campo «Barrio» no puede estar vacío." |

Después de cada error de la base se hace `conexion.rollback()` (`api/database.py`). Todas las consultas usan parámetros (`%s`), nunca texto pegado al SQL.

## Documentación

- [Diagrama E-R final](docs/diagrama_er.md)
- [Diccionario de datos](docs/diccionario_de_datos.md)
- [Script DDL completo](db/ddl.sql)
- [Variables de entorno](api/.env.example)
