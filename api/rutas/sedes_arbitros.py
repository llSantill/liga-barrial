"""CRUD de sedes y de árbitros (tablas de apoyo de los partidos)."""
from fastapi import APIRouter, Depends

from database import ejecutar, get_conexion, no_encontrado
from modelos import ArbitroIn, SedeIn

# ------------------------------- SEDES -------------------------------
sedes = APIRouter(prefix="/sedes", tags=["Sedes"])


@sedes.get("")
def listar_sedes(conexion=Depends(get_conexion)):
    return ejecutar(conexion, "SELECT * FROM sede ORDER BY nombre", modo="todos")


@sedes.get("/{id_sede}")
def obtener_sede(id_sede: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "SELECT * FROM sede WHERE id_sede = %s", (id_sede,), "uno")
    if fila is None:
        raise no_encontrado(f"una sede con ID {id_sede}")
    return fila


@sedes.post("", status_code=201)
def crear_sede(s: SedeIn, conexion=Depends(get_conexion)):
    return ejecutar(conexion, "INSERT INTO sede (nombre, direccion) VALUES (%s, %s) RETURNING *",
                    (s.nombre, s.direccion), "uno")


@sedes.put("/{id_sede}")
def actualizar_sede(id_sede: int, s: SedeIn, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "UPDATE sede SET nombre = %s, direccion = %s WHERE id_sede = %s RETURNING *",
                    (s.nombre, s.direccion, id_sede), "uno")
    if fila is None:
        raise no_encontrado(f"una sede con ID {id_sede}")
    return fila


@sedes.delete("/{id_sede}")
def borrar_sede(id_sede: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "DELETE FROM sede WHERE id_sede = %s RETURNING *", (id_sede,), "uno")
    if fila is None:
        raise no_encontrado(f"una sede con ID {id_sede}")
    return {"mensaje": f"Sede {fila['nombre']} borrada."}


# ------------------------------ ÁRBITROS -----------------------------
arbitros = APIRouter(prefix="/arbitros", tags=["Árbitros"])


@arbitros.get("")
def listar_arbitros(conexion=Depends(get_conexion)):
    return ejecutar(conexion, "SELECT * FROM arbitro ORDER BY nombre", modo="todos")


@arbitros.get("/{id_arbitro}")
def obtener_arbitro(id_arbitro: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "SELECT * FROM arbitro WHERE id_arbitro = %s", (id_arbitro,), "uno")
    if fila is None:
        raise no_encontrado(f"un árbitro con ID {id_arbitro}")
    return fila


@arbitros.post("", status_code=201)
def crear_arbitro(a: ArbitroIn, conexion=Depends(get_conexion)):
    return ejecutar(conexion, "INSERT INTO arbitro (nombre, telefono) VALUES (%s, %s) RETURNING *",
                    (a.nombre, a.telefono), "uno")


@arbitros.put("/{id_arbitro}")
def actualizar_arbitro(id_arbitro: int, a: ArbitroIn, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "UPDATE arbitro SET nombre = %s, telefono = %s WHERE id_arbitro = %s RETURNING *",
                    (a.nombre, a.telefono, id_arbitro), "uno")
    if fila is None:
        raise no_encontrado(f"un árbitro con ID {id_arbitro}")
    return fila


@arbitros.delete("/{id_arbitro}")
def borrar_arbitro(id_arbitro: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "DELETE FROM arbitro WHERE id_arbitro = %s RETURNING *", (id_arbitro,), "uno")
    if fila is None:
        raise no_encontrado(f"un árbitro con ID {id_arbitro}")
    return {"mensaje": f"Árbitro {fila['nombre']} borrado."}
