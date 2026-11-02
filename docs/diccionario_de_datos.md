# Diccionario de datos · Liga Barrial

Base de datos PostgreSQL del torneo eliminatorio de fútbol barrial.
PK = llave primaria · FK = llave foránea · UQ = único · NN = obligatorio.

## equipos
Equipos inscritos en el torneo.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_equipo | SERIAL | PK | Identificador del equipo |
| nombre | VARCHAR(100) | NN, UQ | Nombre del equipo (no se repite) |
| barrio | VARCHAR(100) | NN | Barrio al que representa |

## jugadores
Jugadores de cada equipo.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_jugador | SERIAL | PK | Identificador del jugador |
| nombre | VARCHAR(100) | NN | Nombre completo |
| numero_camiseta | SMALLINT | NN, CHECK 1–99, UQ junto con id_equipo | Número de camiseta; no se repite dentro del mismo equipo |
| telefono | VARCHAR(20) | — | Teléfono de contacto (opcional) |
| estado | VARCHAR(20) | NN, DEFAULT 'activo', CHECK (activo, lesionado, suspendido) | Si puede jugar o no |
| id_equipo | INTEGER | NN, FK → equipos | Equipo al que pertenece |

## arbitro
Árbitros que dirigen los partidos.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_arbitro | SERIAL | PK | Identificador del árbitro |
| nombre | VARCHAR(100) | NN | Nombre completo |
| telefono | VARCHAR(20) | NN, UQ | Teléfono de contacto (no se repite) |

## sede
Canchas donde se juegan los partidos.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_sede | SERIAL | PK | Identificador de la sede |
| nombre | VARCHAR(100) | NN | Nombre de la cancha o unidad deportiva |
| direccion | VARCHAR(150) | NN, UQ | Dirección (no se repite) |

## partido
Partidos del torneo. La columna `id_partido_siguiente` forma la llave eliminatoria (relación recursiva).

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_partido | SERIAL | PK | Identificador del partido |
| fecha | DATE | NN | Día del partido |
| hora | TIME | NN | Hora de inicio |
| resultado | VARCHAR(10) | — | Marcador final, por ejemplo '2-1'. NULL si no se ha jugado |
| id_sede | INTEGER | NN, FK → sede | Cancha donde se juega |
| id_arbitro | INTEGER | FK → arbitro | Árbitro asignado (puede faltar) |
| fase | VARCHAR(20) | — | Cuartos, Semifinal o Final |
| id_partido_siguiente | INTEGER | FK → partido | Partido al que pasa el ganador (NULL en la final) |

## partido_equipo
Tabla intermedia N:M entre partidos y equipos: qué equipos juegan cada partido y con qué rol.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_partido | INTEGER | PK (compuesta), FK → partido | Partido |
| id_equipo | INTEGER | PK (compuesta), FK → equipos | Equipo |
| rol | VARCHAR(10) | NN, CHECK (local, visitante) | Si juega como local o visitante |

## Funciones, triggers y vista

| Objeto | Tipo | Qué hace | Usado por la API en |
|---|---|---|---|
| registrar_partido | Función | Crea un partido validando sede y árbitro | — |
| rehabilitar_jugadores_equipo | Función | Vuelve activos a los suspendidos de un equipo y cuenta cuántos | `POST /equipos/{id}/rehabilitar` |
| asignar_equipos_partido | Función | Asigna local y visitante a un partido | `POST /partidos/{id}/equipos` |
| obtener_estado_plantilla | Función | Calcula % de activos y califica la plantilla | `GET /equipos/{id}/plantilla` |
| trg_validar_max_equipos_partido | Trigger (BEFORE INSERT en partido_equipo) | Impide un tercer equipo en un partido | `POST /partidos/{id}/equipos` |
| trg_validar_estado_jugador | Trigger (BEFORE UPDATE en jugadores) | Valida la camiseta y avisa cuando un jugador vuelve a estar activo | `PUT /jugadores/{id}` |
| trg_validar_disponibilidad_arbitro | Trigger (BEFORE INSERT/UPDATE en partido) | Impide que un árbitro tenga dos partidos a la misma hora | `POST` y `PUT /partidos` |
| vista_resumen_equipos | Vista | Resumen de jugadores por estado y partidos por equipo | `GET /consultas/resumen-equipos` |
