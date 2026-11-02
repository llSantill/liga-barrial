# Diagrama E-R final · Liga Barrial

El modelo tal como quedó implementado en PostgreSQL (`db/ddl.sql`).
GitHub dibuja este diagrama automáticamente. También está como imagen en `docs/diagrama_er.png`.

```mermaid
erDiagram
    EQUIPOS ||--o{ JUGADORES : "tiene"
    EQUIPOS ||--o{ PARTIDO_EQUIPO : "juega"
    PARTIDO ||--o{ PARTIDO_EQUIPO : "enfrenta"
    SEDE ||--o{ PARTIDO : "se juega en"
    ARBITRO |o--o{ PARTIDO : "dirige"
    PARTIDO |o--o{ PARTIDO : "el ganador pasa a"

    EQUIPOS {
        int id_equipo PK
        varchar nombre UK
        varchar barrio
    }
    JUGADORES {
        int id_jugador PK
        varchar nombre
        smallint numero_camiseta "1-99, unico por equipo"
        varchar telefono
        varchar estado "activo, lesionado, suspendido"
        int id_equipo FK
    }
    ARBITRO {
        int id_arbitro PK
        varchar nombre
        varchar telefono UK
    }
    SEDE {
        int id_sede PK
        varchar nombre
        varchar direccion UK
    }
    PARTIDO {
        int id_partido PK
        date fecha
        time hora
        varchar resultado
        int id_sede FK
        int id_arbitro FK
        varchar fase
        int id_partido_siguiente FK "relacion recursiva"
    }
    PARTIDO_EQUIPO {
        int id_partido PK, FK
        int id_equipo PK, FK
        varchar rol "local o visitante"
    }
```
