"""CRUD de equipos + funciones del motor sobre un equipo."""
from typing import Optional

from fastapi import APIRouter, Depends

from database import ejecutar, get_conexion, no_encontrado
from modelos import EquipoIn

router = APIRouter(prefix="/equipos", tags=["Equipos"])


@router.get("")
def listar_equipos(barrio: Optional[str] = None, conexion=Depends(get_conexion)):
    """Lista los equipos. Se puede filtrar por barrio: /equipos?barrio=Belén"""
    if barrio:
        return ejecutar(conexion, "SELECT * FROM equipos WHERE barrio ILIKE %s ORDER BY nombre",
                        (f"%{barrio}%",), "todos")
    return ejecutar(conexion, "SELECT * FROM equipos ORDER BY nombre", modo="todos")


@router.get("/{id_equipo}")
def obtener_equipo(id_equipo: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "SELECT * FROM equipos WHERE id_equipo = %s", (id_equipo,), "uno")
    if fila is None:
        raise no_encontrado(f"un equipo con ID {id_equipo}")
    return fila


@router.post("", status_code=201)
def crear_equipo(equipo: EquipoIn, conexion=Depends(get_conexion)):
    return ejecutar(conexion,
                    "INSERT INTO equipos (nombre, barrio) VALUES (%s, %s) RETURNING *",
                    (equipo.nombre, equipo.barrio), "uno")


@router.put("/{id_equipo}")
def actualizar_equipo(id_equipo: int, equipo: EquipoIn, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion,
                    "UPDATE equipos SET nombre = %s, barrio = %s WHERE id_equipo = %s RETURNING *",
                    (equipo.nombre, equipo.barrio, id_equipo), "uno")
    if fila is None:
        raise no_encontrado(f"un equipo con ID {id_equipo}")
    return fila


@router.delete("/{id_equipo}")
def borrar_equipo(id_equipo: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "DELETE FROM equipos WHERE id_equipo = %s RETURNING *", (id_equipo,), "uno")
    if fila is None:
        raise no_encontrado(f"un equipo con ID {id_equipo}")
    return {"mensaje": f"Equipo {fila['nombre']} borrado."}


# ---------- Lógica del motor: funciones de la Unidad 4 ----------

@router.get("/{id_equipo}/plantilla")
def estado_plantilla(id_equipo: int, conexion=Depends(get_conexion)):
    """Llama la función obtener_estado_plantilla() de PostgreSQL."""
    obtener_equipo(id_equipo, conexion)            # 404 si el equipo no existe
    return ejecutar(conexion, "SELECT * FROM obtener_estado_plantilla(%s)", (id_equipo,), "uno")


@router.post("/{id_equipo}/rehabilitar")
def rehabilitar_jugadores(id_equipo: int, conexion=Depends(get_conexion)):
    """Llama la función rehabilitar_jugadores_equipo(): vuelve activos a los suspendidos."""
    obtener_equipo(id_equipo, conexion)
    return ejecutar(conexion, "SELECT * FROM rehabilitar_jugadores_equipo(%s)", (id_equipo,), "uno")
